module Window
  ( gameInWindow
  )
where

import Data.List (foldl')
import Linear (V2(..), V4(..))
import Control.Monad (unless)
import Data.Text (Text)
import Foreign.C.Types

import qualified SDL
import qualified Graphics.Gloss                  as Gloss
import qualified Graphics.Gloss.Rendering        as Gloss
import qualified Graphics.UI.GLUT.Initialization as GLUT


-- Run an application in a window using a given update, render, and input function
gameInWindow :: Text -> (Int, Int) -> a -> (a -> SDL.Event -> a)
                    -> (a -> a) -> (a -> Gloss.Picture) -> IO ()
gameInWindow title (width, height) initialState input update render = do
  -- Initialise SDL
  SDL.initializeAll
  window <- SDL.createWindow title SDL.defaultWindow { SDL.windowOpenGL = Just SDL.defaultOpenGL
                                                     , SDL.windowInitialSize = V2 (fromIntegral width) (fromIntegral height)
                                                     }

  -- Create opengl context
  context <- SDL.glCreateContext window

  -- Initialise gloss
  glossState <- Gloss.initState

  -- Initailise glut. Used by gloss for text
  -- Otherwise using Gloss.text will cause a runtime crash but could otherwise
  -- be removed to remove the GLUT dependency
  GLUT.initialize "" []

  -- Function to render a gloss picture
  let renderGame = Gloss.displayPicture (width, height) Gloss.black glossState 1.0

  -- Main loop
  let loop state = do -- Poll for events
                      events <- SDL.pollEvents

                      -- Check for a quit event
                      let quit = any (== SDL.QuitEvent) . map SDL.eventPayload $ events

                      -- Run input handler and update game state
                      let newState = update $ foldl' input state events

                      -- Render game
                      renderGame $ render newState

                      -- Swap buffer
                      SDL.glSwapWindow window

                      -- Loop, or quit if requested
                      unless quit (loop newState)

    in loop initialState

  -- Cleanup. Important for ghci use
  SDL.glDeleteContext context
  SDL.destroyWindow window
  SDL.quit
  GLUT.exit

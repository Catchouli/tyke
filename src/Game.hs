module Game
  ( initialGameState
  , update
  , render
  )
where

import qualified Graphics.Gloss                  as Gloss
import qualified Graphics.Gloss.Rendering        as Gloss


data Game = Game { counter :: Int }


-- The initial game state
initialGameState :: Game
initialGameState = Game 0


-- Update the game state
update :: Game -> Game
update game = game { counter = counter game + 1 }

-- Render the game to a Gloss.Picture
render :: Game -> Gloss.Picture
render game =
  let count = counter game
    in Gloss.Pictures [ Gloss.Color Gloss.white $ Gloss.circle 10
                      , Gloss.Color Gloss.white $ Gloss.text (show count)
                      ]

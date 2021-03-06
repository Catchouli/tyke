-- | 
-- Module      :  Framework
-- Description :  Takes the game network and produces IO handlers to run it
-- Copyright   :  (c) 2016 Caitlin Wilks
-- License     :  BSD3
-- Maintainer  :  Caitlin Wilks <mitasuki@gmail.com>
-- 
-- 

module Framework
  ( hostGame
  , TickType
  , InputEvent
  , TickEvent
  , InputHandler
  , TickHandler
  , RenderHandler
  )
where

import Reactive.Banana
import Reactive.Banana.Frameworks

import qualified SDL.Event                       as SDL


-- | A generic event source type alias
type EventSource a = (AddHandler a, Handler a)

-- | The time type to use for the tick event
type TickType = Float

-- | Event types to be used in implementing a game behavior
type InputEvent = Event SDL.Event
type TickEvent = Event TickType
type RenderEvent = Event ()

-- | Handlers returned from hostGame for actually running the game
type InputHandler = SDL.Event -> IO ()
type TickHandler = TickType -> IO ()
type RenderHandler = IO ()

-- | The game render function, where a is the game type (or anything else)
type RenderFunction a = a -> IO ()


-- | Host a game, i.e. set up the necessary events and generate handlers
hostGame :: (Int, Int)
         -> (InputEvent -> TickEvent -> MomentIO (Behavior a))
         -> RenderFunction a
         -> IO (InputHandler, TickHandler, RenderHandler)
hostGame dimensions gameNetwork renderFun = do
  -- Create event sources for SDL events, tick events, and render events
  (ahEvent, hEvent) <- newAddHandler :: IO (EventSource SDL.Event)
  (ahTick, hTick) <- newAddHandler :: IO (EventSource TickType)
  (ahRender, hRender) <- newAddHandler :: IO (EventSource ())

  -- Compile the event network
  network <- compile $ do
    eInput <- fromAddHandler ahEvent
    eTick <- fromAddHandler ahTick
    eRender <- fromAddHandler ahRender

    -- The game behavior :: Behavior a
    bGame <- gameNetwork eInput eTick

    -- Create a game event that fires when the render event does,
    -- then fmap a function Gloss.Picture -> IO () into it to have it
    -- produce an IO () that draws the game
    reactimate (renderFun <$> (bGame <@ eRender))

  actuate network

  return (hEvent, hTick, hRender ())

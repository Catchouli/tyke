{-# LANGUAGE OverloadedStrings #-}

-- | 
-- Module      :  Game.Rendering
-- Description :  Exposes the renderGame function and is the 
--                entry point into the main rendering path for the game
-- Copyright   :  (c) 2016 Caitlin Wilks
-- License     :  BSD3
-- Maintainer  :  Caitlin Wilks <mitasuki@gmail.com>
-- 
-- 

module Game.Rendering
  ( renderGame
  )
where

import ImGui
import Control.Lens
import System.Random
import Game.Data
import Game.Simulation.Camera.Camera
import Game.Terrain
import Game.Terrain.Rendering
import Data.Aeson
import Data.IORef
import Linear
import Graphics.Rendering.FTGL
import Graphics.GL.Compatibility33
import qualified SDL
import qualified Codec.Picture                   as Juicy
import qualified LambdaCube.GL                   as LC
import qualified LambdaCube.GL.Mesh              as LC
import qualified LambdaCube.GL.Type              as LC
import qualified LambdaCube.Linear               as LC
import qualified Data.Map                        as Map
import qualified Data.Vector                     as V
import qualified Data.ByteString                 as BS

-- | Render the game based on its current state

renderGame :: IO (Game -> IO ())
renderGame = do

  -- Set up lambdacube
  let inputSchema = LC.makeSchema $ do
        LC.defObjectArray "objects" LC.Triangles $ do
            "position"        LC.@: LC.Attribute_V3F
            "uv"              LC.@: LC.Attribute_V2F
            "normal"          LC.@: LC.Attribute_V3F
        LC.defUniforms $ do
            "projection"      LC.@: LC.M44F
            "time"            LC.@: LC.Float
            "diffuseTexture"  LC.@: LC.FTexture2D

  -- Allocate storage
  storage <- LC.allocStorage inputSchema
  
  -- Load texture
  Right img <- Juicy.readImage "data/textures/grass_block.png"
  textureData <- LC.uploadTexture2DToGPU img

  -- Load pipeline and generate renderer
  Just pipelineDesc <- decodeStrict <$> BS.readFile "data/pipelines/blocks.json"
  renderer <- LC.allocRenderer pipelineDesc

  -- Generate some random terrain
  terrain <- randomChunk (10, 1, 10)
  let terrainMesh = genChunkMesh terrain
  LC.uploadMeshToGPU terrainMesh >>=
    LC.addMeshToObjectArray storage "objects" []

  -- Set storage
  LC.setStorage renderer storage

  -- Load font
  font <- createTextureFont "data/fonts/droidsans.ttf"
  setFontFaceSize font 22 72

  -- Get start ticks
  start <- SDL.ticks

  -- An IORef for storing the ticks value
  lastFPSUpdateRef <- newIORef start
  lastFPSAvgRef <- newIORef (60 :: Int) -- ^ the initial value is a lie :)
  lastFPSFrameCount <- newIORef (0 :: Int)

  -- The render handler to return
  return $ \game -> do
    -- Get camera matrix and convert it to LC matrix
    let projection = convertMatrix $ game ^. gameCamera ^. camMVPMat
    let viewRot = (game ^. gameCamera ^. camViewMat) & translation .~ (V3 0 0 0)
    let camForward = (V4 0 0 (-1) 0) *! viewRot
    let cameraPos = game ^. gameCamera ^. camPosition
    let cameraFov = game ^. gameCamera ^. camFov

    igBegin "Status"
    igText $ "Camera pos: " ++ show cameraPos
    igText $ "Camera fov: " ++ show cameraFov
    igText $ "Camera forward: " ++ show camForward
    igEnd

    -- Update timer
    ticks <- SDL.ticks

    -- Update fps counter
    modifyIORef lastFPSFrameCount (+1)
    lastFPSUpdate <- readIORef lastFPSUpdateRef

    if (ticks - lastFPSUpdate) >= 1000
       then do avgFps <- readIORef lastFPSFrameCount
               writeIORef lastFPSAvgRef avgFps
               writeIORef lastFPSUpdateRef ticks
               writeIORef lastFPSFrameCount 0
       else return ()

    -- Read average fps
    fps <- readIORef lastFPSAvgRef

    -- Calculate time for unions
    let diff = (fromIntegral (ticks - start)) / 100
    let time = (fromIntegral ticks / 1000)

    -- Update uniforms
    LC.setScreenSize storage 800 600
    LC.updateUniforms storage $ do
      "projection"     LC.@= return projection
      "diffuseTexture" LC.@= return textureData
      "time"           LC.@= return (time :: Float)

    -- Render a frame
    LC.renderFrame renderer


-- | Render stats
-- Unused in favor of imgui, but might need it again

renderStats :: Font -> Int -> IO ()
renderStats font fps = do
  -- Clean up opengl state (after lc render)

  glUseProgram 0
  glColor3f 1 1 1
  glLoadIdentity
  glOrtho 0 800 0 600 0 10

  -- Disable depth test so we can draw on top of lc render
  glDisable GL_DEPTH_TEST

  -- Draw text
  glPushMatrix

  glTranslatef 50 50 0
  renderFont font ("FPS: " ++ show fps ++ "hz") All
  
  glPopMatrix

  -- Restore depth test it's probably important
  glEnable GL_DEPTH_TEST


-- | Convert a linear matrix to a lambacube one..

convertMatrix :: M44 Float -> LC.M44F
convertMatrix mat = let V4 (V4 a b c d)
                           (V4 e f g h)
                           (V4 i j k l)
                           (V4 m n o p) = mat
                    in LC.V4 (LC.V4 a e i m)
                             (LC.V4 b f j n)
                             (LC.V4 c g k o)
                             (LC.V4 d h l p)

module Main where
import Codec.FFmpeg
import Codec.Picture
import Control.Monad (forM_)
import qualified Data.Vector.Storable as V
import Graphics.Rasterific
import Graphics.Rasterific.Texture
import Graphics.Rasterific.Transformations
import Linear

-- | The Rasterific logo sample shape.
logo :: Int -> Bool -> Vector -> [Primitive]
logo size inv offset = map BezierPrim . bezierFromPath . way $ map (^+^ offset)
    [ (V2   0  is)
    , (V2   0   0)
    , (V2  is   0)
    , (V2 is2   0)
    , (V2 is2  is)
    , (V2 is2 is2)
    , (V2  is is2)
    , (V2  0  is2)
    , (V2  0   is)
    ]
  where is = fromIntegral size
        is2 = is + is

        way | inv = reverse
            | otherwise = id

-- | Sample a quadratic bezier curve.
bezierInterp :: Bezier -> [Point]
bezierInterp (Bezier a b c) = go 0
  where v1 = b - a
        v2 = c - b
        go t
          | t >= 1 = []
          | otherwise = let q0 = a + v1 ^* t
                            q1 = b + v2 ^* t
                            vq = q1 - q0
                        in q0 + t *^ vq : (go $! t + 0.05)

-- | Our animation path.
path :: [Point]
path = concatMap bezierInterp $
       bezierFromPath [ (V2   0  is)
                      , (V2   0   0)
                      , (V2  (is+5)   0)
                      , (V2 (is2+10)   0)
                      , (V2 (is2+10)  is)
                      , (V2 (is2+10) is2)
                      , (V2  (is+5) is2)
                      , (V2  0  is2)
                      , (V2  0   is)
                      ]
  where is = 15
        is2 = is + is

background, blue :: PixelRGB8
background = PixelRGB8 128 128 128
blue = PixelRGB8 0 020 150

-- | A ring with a drop-shadow on the inside. The texture is repeated,
-- resulting in concentric rings centered at @(200,200)@.
bgGrad :: Texture PixelRGB8
bgGrad = withSampler SamplerRepeat $
         radialGradientTexture gradDef (V2 200 200) 100
  where gradDef = [(0  , PixelRGB8 255 255 255)
                  ,(0.5, PixelRGB8 255 255 255)
                  ,(0.5, PixelRGB8 255 255 255)
                  ,(0.525, PixelRGB8 255 255 255)
                  ,(0.675, PixelRGB8 128 128 128)
                  ,(0.75, PixelRGB8 100 149 237)
                  ,(1, PixelRGB8 100 149 237)
                  ]

-- | Adapted from the Rasterific logo example.
logoTest :: Texture PixelRGB8 -> Vector -> Image PixelRGB8
logoTest texture insetOrigin = renderDrawing 350 350 background (bg >> drawing)
  where 
    beziers = logo 40 False $ V2 10 10
    inverse = logo 20 True $ (V2 20 20 + insetOrigin)
    bg = withTexture bgGrad . fill $ rectangle (V2 0 0) 350 350
    drawing = withTexture texture . fill 
            . transform (applyTransformation $ scale 3.5 3.5)
            $ beziers ++ inverse

-- | Animate the logo and write it to a video file!
main :: IO ()
main = do initFFmpeg
          -- Change the output file extension to ".gif" to get an
          -- animated gif! We can get a small GIF file by setting
          -- 'epPixelFormat' to 'avPixFmtRgb8', but it might not look
          -- very good.
          w <- frameWriter params "logo.mov"
          forM_ path $
            w . Just . V.unsafeCast . imageData . logoTest (uniformTexture blue)
          w Nothing
  where params = defaultParams 350 350
        -- tinyGif = params { epPixelFormat = Just avPixFmtRgb8 }
        -- prettyGif = params { preset = "dither" }
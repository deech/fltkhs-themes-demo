{-# LANGUAGE ImplicitParams, OverloadedStrings, ScopedTypeVariables, FlexibleContexts #-}
module Main where
import qualified Graphics.UI.FLTK.LowLevel.FL as FL
import Graphics.UI.FLTK.LowLevel.Fl_Types
import Graphics.UI.FLTK.Theme.Simple
import Graphics.UI.FLTK.LowLevel.Fl_Enumerations
import Control.Arrow
import qualified Data.Text as T
buttonCb :: Ref Button -> IO ()
buttonCb b' = do
  l' <- getLabel b'
  if (l' == "Hello world")
    then setLabel b' "Goodbye world"
    else setLabel b' "Hello world"

ui :: (?loaded :: Loaded) => IO ()
ui = do
 window <- windowNew
           (Size (Width 500) (Height 500))
           Nothing
           Nothing
 begin window
 b' <- buttonNew
        (Rectangle (Position (X 50) (Y 50)) (Size (Width 100) (Height 75)))
        (Just "Hello world")
 setCallback b' buttonCb
 end window
 showWidget window

main :: IO ()
main = loadTheme >>= (\loaded -> let ?loaded = loaded in ui >> FL.run >> FL.flush)

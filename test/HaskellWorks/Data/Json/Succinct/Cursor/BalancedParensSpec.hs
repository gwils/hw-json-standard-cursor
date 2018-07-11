{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}

module HaskellWorks.Data.Json.Succinct.Cursor.BalancedParensSpec(spec) where

import Data.String
import HaskellWorks.Data.Bits.BitShown
import HaskellWorks.Data.Json.Internal.MakeIndex
import HaskellWorks.Data.Json.Succinct.Cursor.BlankedJson
import Test.Hspec

import qualified Data.ByteString as BS

{-# ANN module ("HLint: Ignore Redundant do"        :: String) #-}

spec :: Spec
spec = describe "HaskellWorks.Data.Json.Succinct.Cursor.BalancedParensSpec" $ do
  it "Blanking JSON should not contain strange characters 1" $ do
    let blankedJson = BlankedJson ["[ [],", "[]]"]
    let bp = BitShown $ BS.concat (blankedJsonToBalancedParens2 (getBlankedJson blankedJson))
    bp `shouldBe` fromString "11111111 11111111 00000000 11111111 00000000 00000000"
  it "Blanking JSON should not contain strange characters 2" $ do
    let blankedJson = BlankedJson ["[ [],", "[]]"]
    let bp = BitShown $ BS.concat ((compressWordAsBit . blankedJsonToBalancedParens2) (getBlankedJson blankedJson))
    bp `shouldBe` fromString "11010000"

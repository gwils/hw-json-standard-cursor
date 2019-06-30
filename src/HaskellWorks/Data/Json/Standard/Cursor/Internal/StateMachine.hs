{-# LANGUAGE BinaryLiterals             #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings          #-}

module HaskellWorks.Data.Json.Standard.Cursor.Internal.StateMachine
  ( lookupPhiTable
  , lookupTransitionTable
  , phiTable
  , phiTableSimd
  , transitionTable
  , transitionTableSimd
  , IntState(..)
  , State(..)
  ) where

import Data.Word
import HaskellWorks.Data.Bits.BitWise

import qualified Data.Vector                                           as DV
import qualified Data.Vector.Storable                                  as DVS
import qualified HaskellWorks.Data.Json.Standard.Cursor.Internal.Word8 as W8

{-# ANN module ("HLint: ignore Redundant guard"  :: String) #-}

newtype IntState = IntState Int deriving (Eq, Ord, Show, Num)

data State = InJson | InString | InEscape | InValue deriving (Eq, Enum, Bounded, Show)

phiTable :: DV.Vector (DVS.Vector Word8)
phiTable = DV.constructN 5 gos
  where gos :: DV.Vector (DVS.Vector Word8) -> DVS.Vector Word8
        gos v = DVS.constructN 256 go
          where vi = DV.length v
                go :: DVS.Vector Word8 -> Word8
                go u = fromIntegral (snd (stateMachine (fromIntegral ui) (toEnum vi)))
                  where ui = DVS.length u
{-# NOINLINE phiTable #-}

phiTable2 :: DVS.Vector Word8
phiTable2 = DVS.constructN (4 * fromIntegral iLen) go
  where iLen = 256 :: Int
        go :: DVS.Vector Word8 -> Word8
        go u = fromIntegral (snd (stateMachine (fromIntegral ui) (toEnum (fromIntegral uj))))
          where (uj, ui) = fromIntegral (DVS.length u) `divMod` iLen
{-# NOINLINE phiTable2 #-}

lookupPhiTable :: IntState -> Word8 -> Word8
lookupPhiTable (IntState s) w = DVS.unsafeIndex phiTable2 (s * 256 + fromIntegral w)
{-# INLINE lookupPhiTable #-}

phiTableSimd :: DVS.Vector Word32
phiTableSimd = DVS.constructN 256 go
  where go :: DVS.Vector Word32 -> Word32
        go v =  (snd (stateMachine vi InJson  ) .<.  0) .|.
                (snd (stateMachine vi InString) .<.  8) .|.
                (snd (stateMachine vi InEscape) .<. 16) .|.
                (snd (stateMachine vi InValue ) .<. 24)
          where vi = fromIntegral (DVS.length v)
{-# NOINLINE phiTableSimd #-}

transitionTable :: DV.Vector (DVS.Vector Word8)
transitionTable = DV.constructN 5 gos
  where gos :: DV.Vector (DVS.Vector Word8) -> DVS.Vector Word8
        gos v = DVS.constructN 256 go
          where vi = DV.length v
                go :: DVS.Vector Word8 -> Word8
                go u = fromIntegral (fromEnum (fst (stateMachine ui (toEnum vi))))
                  where ui = fromIntegral (DVS.length u)
{-# NOINLINE transitionTable #-}

transitionTable2 :: DVS.Vector Word8
transitionTable2 = DVS.constructN (4 * fromIntegral iLen) go
  where iLen = 256 :: Int
        go :: DVS.Vector Word8 -> Word8
        go u = fromIntegral (fromEnum (fst (stateMachine (fromIntegral ui) (toEnum (fromIntegral uj)))))
          where (uj, ui) = fromIntegral (DVS.length u) `divMod` iLen
{-# NOINLINE transitionTable2 #-}

lookupTransitionTable :: IntState -> Word8 -> IntState
lookupTransitionTable (IntState s) w = fromIntegral (DVS.unsafeIndex transitionTable2 (s * 256 + fromIntegral w))
{-# INLINE lookupTransitionTable #-}

transitionTableSimd :: DVS.Vector Word64
transitionTableSimd = DVS.constructN 256 go
  where go :: DVS.Vector Word64 -> Word64
        go v =  fromIntegral (fromEnum (fst (stateMachine vi InJson  ))) .|.
                fromIntegral (fromEnum (fst (stateMachine vi InString))) .|.
                fromIntegral (fromEnum (fst (stateMachine vi InEscape))) .|.
                fromIntegral (fromEnum (fst (stateMachine vi InValue )))
          where vi = fromIntegral (DVS.length v)
{-# NOINLINE transitionTableSimd #-}

stateMachine :: Word8 -> State -> (State, Word32)
stateMachine c InJson   | W8.isOpen c         = (InJson  , 0b110)
stateMachine c InJson   | W8.isClose c        = (InJson  , 0b001)
stateMachine c InJson   | W8.isDelim c        = (InJson  , 0b000)
stateMachine c InJson   | W8.isValueChar c    = (InValue , 0b111)
stateMachine c InJson   | W8.isDoubleQuote c  = (InString, 0b111)
stateMachine _ InJson   | otherwise           = (InJson  , 0b000)
stateMachine c InString | W8.isDoubleQuote c  = (InJson  , 0b000)
stateMachine c InString | W8.isBackSlash c    = (InEscape, 0b000)
stateMachine _ InString | otherwise           = (InString, 0b000)
stateMachine _ InEscape | otherwise           = (InString, 0b000)
stateMachine c InValue  | W8.isOpen c         = (InJson  , 0b110)
stateMachine c InValue  | W8.isClose c        = (InJson  , 0b001)
stateMachine c InValue  | W8.isDelim c        = (InJson  , 0b000)
stateMachine c InValue  | W8.isValueChar c    = (InValue , 0b000)
stateMachine _ InValue  | otherwise           = (InJson  , 0b000)
{-# INLINE stateMachine #-}

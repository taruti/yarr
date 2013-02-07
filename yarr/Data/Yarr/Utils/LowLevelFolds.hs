
module Data.Yarr.Utils.LowLevelFolds where

import GHC.Exts
import Data.Yarr.Utils.FixedVector as V


fill# :: (Int -> IO a)
      -> (Int -> a -> IO ())
      -> Int# -> Int#
      -> IO ()
{-# INLINE fill# #-}
fill# get write start# end# =
    let {-# INLINE go# #-}
        go# i#
            | i# >=# end# = return ()
            | otherwise   = do
                let i = (I# i#)
                a <- get i
                write i a
                go# (i# +# 1#)
    in go# start#
    
unrolledFill#
    :: forall a uf. Arity uf
    => uf
    -> (a -> IO ())
    -> (Int -> IO a)
    -> (Int -> a -> IO ())
    -> Int# -> Int#
    -> IO ()
{-# INLINE unrolledFill# #-}
unrolledFill# unrollFactor tch get write start# end# =
    let !(I# uf#) = arity unrollFactor
        lim# = end# -# uf#
        {-# INLINE go# #-}
        go# i#
            | i# ># lim# = rest# i#
            | otherwise  = do
                let is :: VecList uf Int
                    is = V.generate (+ (I# i#))
                as <- V.mapM get is
                V.mapM_ tch as
                V.zipWithM_ write is as
                go# (i# +# uf#)

        {-# INLINE rest# #-}
        rest# i#
            | i# >=# end# = return ()
            | otherwise   = do
                let i = (I# i#)
                a <- get i
                tch a
                write i a
                rest# (i# +# 1#)
    in go# start#


foldl#
    :: (b -> Int -> a -> IO b)
    -> b
    -> (Int -> IO a)
    -> Int# -> Int#
    -> IO b
{-# INLINE foldl# #-}
foldl# reduce z get start# end# =
    let {-# INLINE go# #-}
        go# i# b
            | i# >=# end# = return b
            | otherwise   = do
                let i = (I# i#)
                a <- get i
                b' <- reduce b i a
                go# (i# +# 1#) b'
    in go# start# z

unrolledFoldl#
    :: forall a b uf. Arity uf
    => uf
    -> (a -> IO ())
    -> (b -> Int -> a -> IO b)
    -> b
    -> (Int -> IO a)
    -> Int# -> Int#
    -> IO b
{-# INLINE unrolledFoldl# #-}
unrolledFoldl# unrollFactor tch reduce z get start# end# =
    let !(I# uf#) = arity unrollFactor
        lim# = end# -# uf#
        {-# INLINE go# #-}
        go# i# b
            | i# ># lim# = rest# i# b
            | otherwise  = do
                let is :: VecList uf Int
                    is = V.generate (+ (I# i#))
                as <- V.mapM get is
                V.mapM_ tch as
                b' <- V.foldM
                        (\b (i, a) -> reduce b i a) b
                        (V.zipWith (,) is as)
                go# (i# +# uf#) b'

        {-# INLINE rest# #-}
        rest# i# b
            | i# >=# end# = return b
            | otherwise   = do
                let i = (I# i#)
                a <- get i
                tch a
                b' <- reduce b i a
                rest# (i# +# 1#) b'

    in go# start# z


foldr#
    :: (Int -> a -> b -> IO b)
    -> b
    -> (Int -> IO a)
    -> Int# -> Int#
    -> IO b
{-# INLINE foldr# #-}
foldr# reduce z get start# end# =
    let {-# INLINE go# #-}
        go# i# b
            | i# <# start# = return b
            | otherwise    = do
                let i = (I# i#)
                a <- get i
                b' <- reduce i a b
                go# (i# -# 1#) b'
    in go# (end# -# 1#) z

unrolledFoldr#
    :: forall a b uf. Arity uf
    => uf
    -> (a -> IO ())
    -> (Int -> a -> b -> IO b)
    -> b
    -> (Int -> IO a)
    -> Int# -> Int#
    -> IO b
{-# INLINE unrolledFoldr# #-}
unrolledFoldr# unrollFactor tch reduce z get start# end# =
    let !(I# uf#) = arity unrollFactor
        lim# = start# +# uf# -# 1#
        {-# INLINE go# #-}
        go# i# b
            | i# <# lim# = rest# i# b
            | otherwise  = do
                let is :: VecList uf Int
                    is = V.generate ((I# i#) -)
                as <- V.mapM get is
                V.mapM_ tch as
                b' <- V.foldM
                        (\b (i, a) -> reduce i a b) b
                        (V.zipWith (,) is as)
                go# (i# -# uf#) b'

        {-# INLINE rest# #-}
        rest# i# b
            | i# <# start# = return b
            | otherwise    = do
                let i = (I# i#)
                a <- get i
                tch a
                b' <- reduce i a b
                rest# (i# -# 1#) b'

    in go# (end# -# 1#) z


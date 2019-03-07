{-# LANGUAGE GADTs #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

-- | A BUNCH OF SHIT STOLEN FROM COMPDATA + POLYKINDS/SING stuff from me, TODO UPSTREAM PR
module Util.HRecursionSchemes where

import           Control.Monad
import           Data.Singletons
import           Data.Functor.Const (Const)
import qualified Data.Functor.Compose as FC
import           Data.Kind (Type)

type NatM m f g = forall i. SingI i => f i -> m (g i)

type f :-> g = forall (i :: k) . SingI i => f i -> g i
type f :=> a = forall (i :: k) . SingI i => f i -> a

class HFunctor (h :: (k -> Type) -> k -> Type) where
    hfmap :: (f :-> g) -> h f :-> h g

newtype Const' a h i = Const' { unConst' :: a}

instance HFunctor (Const' x) where
  hfmap _ (Const' x) = Const' x

instance (Functor f) => HFunctor (FC.Compose f) where
  hfmap f (FC.Compose xs) = FC.Compose (fmap f xs)

-- note: just the bit I need for cataM/anaM
class HTraversable t where
    hmapM :: (Monad m)
          => (forall i . SingI i =>    f  i -> m (   g  i))
          -> (forall i . SingI i => (t f) i -> m ((t g) i))

instance (Traversable f) => HTraversable (FC.Compose f) where
  hmapM nat (FC.Compose xs) = FC.Compose <$> traverse nat xs

data Cxt h f a i where
    Term ::  f (Cxt h f a) i -> Cxt h f a i
    Hole :: a i -> Cxt Hole f a i

data Hole
data NoHole

type Context = Cxt Hole

type Term f = Cxt NoHole f (Const ())

unTerm :: Term f t -> f (Term f) t
unTerm (Term t) = t

data Pair f g h i = Pair (f h i) (g h i)

instance (HFunctor f) => HFunctor (Cxt h f) where
    hfmap f (Hole x) = Hole (f x)
    hfmap f (Term t) = Term (hfmap (hfmap f) t)

instance (HFunctor f, HFunctor g) => HFunctor (Pair f g) where
    hfmap f (Pair x y) = Pair (hfmap f x) (hfmap f y)

type Alg f e = f e :-> e

cata :: forall f a. HFunctor f => Alg f a -> Term f :-> a
cata f = run
    where run :: Term f :-> a
          run (Term t) = f (hfmap run t)


type AlgM m f e = NatM m (f e) e

-- | This is a monadic version of 'cata'.
cataM :: forall f m a. (HTraversable f, Monad m) =>
         AlgM m f a -> NatM m (Term f) a
cataM alg = run
    where run :: NatM m (Term f) a
          run (Term x) = alg =<< hmapM run x

type Coalg f a = a :-> f a

ana :: forall f a. HFunctor f => Coalg f a -> (a :-> Term f)
ana f = run
    where run :: a :-> Term f
          run t = Term $ hfmap run (f t)

type CoalgM m f a = NatM m a (f a)

anaM :: forall a m f. (HTraversable f, Monad m)
          => CoalgM m f a -> NatM m a (Term f)
anaM f = run
    where run :: NatM m a (Term f)
          run t = liftM Term $ f t >>= hmapM run

type CVCoalg f a = a :-> f (Context f a)

futu :: forall f a . HFunctor f => CVCoalg f a -> a :-> Term f
futu coa = ana run . Hole
    where run :: Coalg f (Context f a)
          run (Hole a) = coa a
          run (Term v) = v

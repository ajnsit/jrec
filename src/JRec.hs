{-# LANGUAGE GADTs #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TypeApplications #-}

module JRec
  ( unField,
    (:=) (..),
    Rec,
    pattern Rec,
    append,
    union,
    insert,
    insertOrSet,
  )
where

import Control.Lens (coerced, (&), (.~), (^.))
import qualified "generic-lens" Data.Generics.Product.Fields as GL
import qualified "generic-optics" Data.Generics.Product.Fields as GO
import qualified "generic-lens" Data.Generics.Wrapped as GL
import qualified "generic-optics" Data.Generics.Wrapped as GO
import Data.Proxy
import GHC.Exts (Any)
import GHC.OverloadedLabels
import GHC.TypeLits
import Generic.Data
import JRec.Field
import JRec.Internal (Rec, (:=) (..))
import qualified JRec.Internal as R
import JRec.Tuple
import Unsafe.Coerce

----------------------------------------------------------------------------
-- unField
----------------------------------------------------------------------------

unField :: field ~ field' => R.FldProxy field -> (field' R.:= value) -> value
unField _ (_ R.:= value) = value

----------------------------------------------------------------------------
-- Other operations
----------------------------------------------------------------------------

-- Appends records, without removing duplicates.
--
-- O(n + m) type check complexity.
--
-- FIXME: See spec for a bug when there are duplicates.
append ::
  forall lhs rhs res.
  ( KnownNat (R.RecSize lhs),
    KnownNat (R.RecSize rhs),
    KnownNat (R.RecSize lhs + R.RecSize rhs),
    res ~ R.RecAppend lhs rhs,
    R.RecCopy lhs lhs res,
    R.RecCopy rhs rhs res
  ) =>
  Rec lhs ->
  Rec rhs ->
  Rec res
append = R.combine

-- Merges records, removing duplicates
--
-- Left-biased. Does not sort.
--
-- O(n * m) type check complexity.
union ::
  forall lhs rhs res.
  ( KnownNat (R.RecSize lhs),
    KnownNat (R.RecSize rhs),
    KnownNat (R.RecSize res),
    res ~ R.Union lhs rhs,
    R.RecCopy lhs lhs res,
    R.RecCopy rhs rhs res
  ) =>
  Rec lhs ->
  Rec rhs ->
  Rec res
union = R.union

-- | Insert a field into a record that does not already contain it
--
-- O(n) type check complexity.
insert ::
  forall label value lts res.
  ( KnownNat (1 + R.RecSize lts),
    KnownNat (R.RecSize lts),
    KnownSymbol label,
    R.RecCopy lts lts res,
    res ~ ((label := value) : lts),
    R.RemoveAccessTo label lts ~ lts
  ) =>
  label := value ->
  Rec lts ->
  Rec res
insert = R.combine . Rec

-- | Insert a field into a record. Set it if it already exists
--
-- O(n) type check complexity.
insertOrSet ::
  forall label value rhs res.
  ( KnownNat (R.RecSize rhs),
    KnownNat (R.RecSize res),
    KnownNat (R.RecTyIdxH 0 label res),
    KnownSymbol label,
    value ~ R.RecTy label res,
    R.Reverse (R.Insert (label := value) (R.Reverse rhs)) ~ res,
    R.RecCopy rhs rhs res
  ) =>
  label := value ->
  Rec rhs ->
  Rec res
insertOrSet = R.insert

----------------------------------------------------------------------------
-- generic-lens
----------------------------------------------------------------------------

instance {-# OVERLAPPING #-} (R.Set field fields a' ~ fields', R.Set field fields' a ~ fields, R.Has field fields a, R.Has field fields' a') => GL.HasField field (Rec fields) (Rec fields') a a' where
  field = R.lens (R.FldProxy @field)

instance {-# OVERLAPPING #-} (R.Set field fields a ~ fields, R.Has field fields a) => GL.HasField' field (Rec fields) a where
  field' = R.lens (R.FldProxy @field)

----------------------------------------------------------------------------
-- generic-optics
----------------------------------------------------------------------------

instance {-# OVERLAPPING #-} (R.Set field fields a' ~ fields', R.Set field fields' a ~ fields, R.Has field fields a, R.Has field fields' a') => GO.HasField field (Rec fields) (Rec fields') a a' where
  field = R.opticLens (R.FldProxy @field)

instance {-# OVERLAPPING #-} (R.Set field fields a ~ fields, R.Has field fields a) => GO.HasField' field (Rec fields) a where
  field' = R.opticLens (R.FldProxy @field)

pattern Rec ::
  ( RecTuple tuple fields
  ) =>
  tuple ->
  Rec fields
pattern Rec a <-
  (toTuple -> a)
  where
    Rec = fromTuple

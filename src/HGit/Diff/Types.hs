module HGit.Diff.Types where

data Diff = FileModified
          | FileReplacedWithDir
          | DirReplacedWithFile
          | EntityDeleted
          | EntityCreated
  deriving (Show)

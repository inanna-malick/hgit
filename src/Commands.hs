
module Commands (Command(..), parse)where

import Options.Applicative
import Data.List.NonEmpty
import Data.Semigroup ((<>))

import HGit.Types


parse :: IO Command
parse = execParser opts
  where
    opts = info (parser <**> helper)
      ( fullDesc
     <> progDesc "Print a greeting for TARGET"
     <> header "hello - a test for optparse-applicative" )

data PathMatcher = WildCard | Concrete String

data Command
  -- switch directory state to that of new branch (nuke and rebuild via store)
  -- fails if any changes exist in current dir (diff via status /= [])
  = CheckoutBranch BranchName (NonEmpty PathMatcher)
  -- create new branch with same root commit as current branch. changes are fine
  | MkBranch BranchName
  -- add everything in current repo to the current branch in a new commit w/ msg
  -- and update current branch
  -- initialize repo in current directory with provided name
  | InitRepo
  | MkCommit CommitMessage
  | GetStatus -- get status of current repo (diff current state vs. that of last commit on branch)
  | GetDiff BranchName BranchName

parser :: Parser Command
parser
  = subparser
     ( command "checkout" (info checkoutOptions  ( progDesc "checkout a branch"     ))
    <> command "branch"   (info branchOptions    ( progDesc "create a new branch"   ))
    <> command "init"     (info initOptions      ( progDesc "create a new repo"     ))
    <> command "commit"   (info commitOptions    ( progDesc "create a new commit"   ))
    <> command "status"   (info statusOptions    ( progDesc "show repo status"      ))
    <> command "diff"     (info diffOptions      ( progDesc "show diff of branches" ))
      )
  where
    checkoutOptions  = undefined
    branchOptions  = undefined
    initOptions  = undefined
    commitOptions  = undefined
    statusOptions  = undefined
    diffOptions  = undefined
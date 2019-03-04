module Main where

--------------------------------------------
import           Data.Functor.Const
import qualified Data.Functor.Compose as FC
import qualified System.Directory as Dir
--------------------------------------------
import           Commands
import           FileIO
import           HGit.Diff (diffMerkleDirs)
import           HGit.Repo
import           HGit.Types
import           Util.MyCompose
import           Util.HRecursionSchemes
import           HGit.Serialization (emptyDirHash)
import           HGit.Store
import           HGit.Store.Deref
--------------------------------------------

-- TODO: new app plan - minimum required for cool demo, basically - idea is diffing branches, checking them out, etc
-- checkout: reset current directory to branch - only if no changes (determined by reading current dir and doing diff)
-- idea: --lazy flag, just touches all files but only grabs those you request
--       note: this kinda breaks diffing against current directory, BUT I can have my own format:
--             [filename].hgit.lazy.file OR [dirname].hgit.lazy.dir
--             could then just disallow this postfix on ingestion to avoid possibility of overlap
--             anyway, then just have that be read as diff of subtree and include lazyness in file
--             read... fuck, this is nontrivial. I will do this as part of _V2_ - seriously, nontrivial..
--             that said, it's a hecking good idea.. w/o it no real need for the search path thing either tbh..
--             ok, no worries - branch/checkout/etc is PERFECT for demo v1 thingy, next can be w/e lol
-- idea: that then requires checkout w/ file path (would checkout file and all subdirs and mk same)
--       could just have optional 'only this path if it exists' string and run off that
--       type idea: IO $ Either FileDoesntExistError $ IO ()
--       can then build up actions _but_ only run them (eg intermediate mkdir calls)
--       if no named file is missing
--       this allows for tree traversal and not just single file, have input be list of file parts
--       and use state (as elsewhere) to manage stack - can use * at any level to select all files or dirs and run next thing in list, if * is end of list is treated as Nothing (match all)
--       note: --lazy and --match can be applied to the same traversal via the same code


-- NOTE: hgit is a nice pun name (unintentional), includes features of both hg and git comma lmao

-- NOTE: might as well just keep popping up the directory tree to find that hgit file w/ branch mappings anyway, lol - (or .hgit/branches, with .hgit/store as the store (removes need for flag))

-- NOTE NOTE NOTE
-- can replicate distributed nature of git pretty handily by just having a foreign store send
-- over list of branch names and pulling from said store via http or w/e
-- that's.. pretty easy, and I think would probably help this be a v. compelling demo

-- NOTE NOTE NOTE
-- for status: can setup reader that builds structure from local fs (via file/dir reads)
--  ..tracking what is substantiated locally vs. not is hard.. must be in repostate! can do.
--  note: done (probably works)

main :: IO ()
main = parse >>= \case
  InitRepo -> do
    mkHgitDir -- mk .hgit and .hgit/store dirs
    writeState initialRepoState
  CheckoutBranch branch _ -> do
    store        <- mkStore
    base         <- baseDir
    repostate    <- readState

    -- throw if target branch name not known
    targetCommit <- getBranch branch repostate >>= sDeref store

    diffs        <- status base repostate store
    if not (null diffs)
      then do
        putStrLn "directory modified, cannot checkout. Changes:"
        print diffs
        fail "womp womp"
      else do
        currentCommit <- getBranch (currentBranch repostate) repostate >>= sDeref store
        topLevelCurrentDir <- sDeref store $ commitRoot currentCommit
        let toDelete = dirEntries topLevelCurrentDir
        -- NUCLEAR: basically only use in a docker container for a bit, lol
        _ <- traverse (Dir.removeDirectoryRecursive . fst) toDelete

        x <- strictDeref'' . lazyDeref store $ commitRoot targetCommit
        writeTree base x

  MkBranch branch -> do
    repostate <- readState
    current   <- getBranch (currentBranch repostate) repostate
    writeState $ repostate
               { branches      = branches repostate ++ [(branch, getConst current)]
               , currentBranch = branch
               } -- same pointer as current, same dir state - just add new branch -> pointer mapping
  MkCommit msg -> do
    store             <- mkStore
    repostate         <- readState
    base              <- baseDir
    currentCommitHash <- getBranch (currentBranch repostate) repostate
    currentStateHash  <- readAndStore store base
    let commit = Commit msg currentStateHash currentCommitHash
    hash <- sUploadShallow store commit
    writeState $ repostate
               { branches = (\(x,p) ->
                               if x == (currentBranch repostate)
                                 then (x, p)
                                 else (x, getConst hash)
                            )
                        <$> branches repostate
               }

  GetStatus -> do
    store     <- mkStore
    repostate <- readState
    base      <- baseDir
    diffs     <- status base repostate store
    print diffs

  GetDiff branch1 branch2 -> do
    store     <- mkStore
    repostate <- readState
    commit1  <- getBranch branch1 repostate >>= sDeref store
    commit2  <- getBranch branch2 repostate >>= sDeref store
    diffs     <- diffMerkleDirs store (commitRoot commit1) (commitRoot commit2)
    print diffs

  where
    status base repostate store = do
      currentCommit <- getBranch (currentBranch repostate) repostate >>= sDeref store
      currentStateHash  <- readAndStore store base
      diffMerkleDirs store (commitRoot currentCommit) currentStateHash


-- IDEA: use 'Pair (Const HashPointer) f' instead of (,) HashPointer :+ f
commitRoot
  :: HGit (Term (FC.Compose HashIndirect :++ HGit)) 'CommitTag
  -> Const HashPointer 'DirTag
commitRoot (Commit _ (Term (HC (FC.Compose (C (p, _))))) _) = Const p
commitRoot NullCommit        = emptyDirHash

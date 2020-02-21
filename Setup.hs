{-# LANGUAGE CPP #-}
module Main (main) where

import Control.Monad
import Distribution.Simple
import Distribution.Simple.Setup
import Distribution.Simple.Program
import Distribution.Simple.LocalBuildInfo
import Distribution.PackageDescription
import System.FilePath
import System.Environment (getEnv, setEnv)
import Distribution.Simple.LocalBuildInfo (installedPkgs)
import Distribution.Simple.PackageIndex
import Distribution.Simple.Utils(rawSystemStdout)
import Distribution.Package (Dependency, PackageName)
import Distribution.Verbosity(normal)
import Distribution.Version (anyVersion)
import Distribution.System (buildOS, OS(Windows, OSX))
import Distribution.InstalledPackageInfo
import System.Directory(doesFileExist)
import System.IO.Error
import Distribution.Simple.Setup
import qualified Distribution.Simple.AssetBundle as Bundle (postCopy, depsWithData)

#if defined(MIN_VERSION_Cabal) && MIN_VERSION_Cabal(2,0,0)
_PackageName = mkPackageName
#else
_PackageName = PackageName
#endif

main :: IO ()
main = defaultMainWithHooks (simpleUserHooks { buildHook = myBuildHook })

fltkhsDependency :: LocalBuildInfo -> [(Version, [InstalledPackageInfo])]
fltkhsDependency local_bld_info = lookupDependency (installedPkgs local_bld_info) (_PackageName "fltkhs") anyVersion

myBuildHook :: PackageDescription -> LocalBuildInfo -> UserHooks -> BuildFlags -> IO ()
myBuildHook pkg_descr local_bld_info user_hooks bld_flags =
  let fltkhsDependency = lookupDependency (installedPkgs local_bld_info) (_PackageName "fltkhs") anyVersion
      keepBuilding = (buildHook simpleUserHooks) pkg_descr local_bld_info user_hooks bld_flags
  in
  case fmap snd fltkhsDependency of
    [] -> keepBuilding
    (packageInfo:_):_ ->
       mapM_ (updateEnv "LIBRARY_PATH") (libraryDirs packageInfo) >>
       keepBuilding

updateEnv :: String -> String -> IO ()
updateEnv env value = do
  old <- tryIOError (getEnv env)
  setEnv env ((either (const value)
                      (\old' -> value ++
                               (case buildOS of
                                  Windows -> ";"
                                  _ -> ":") ++
                               old'
                      )
                      old))
cygpath o p =
  let removeTrailingNewline = head . lines  in
  removeTrailingNewline<$>(rawSystemStdout normal "cygpath" [o,  p])

gatherWindowsExtraFiles :: IO [FilePath]
gatherWindowsExtraFiles =
  let requiredDlls =
        [
         "libstdc++-6.dll"
        ,"libgcc_s_seh-1.dll"
        ,"libwinpthread-1.dll"
        ]
  in do
    ghcPath <- rawSystemStdout normal "sh" ["-c", "which ghc"]
    fs <- mapM (cygpath "-w") (map (\f -> ((takeDirectory . takeDirectory) ghcPath) </> "mingw" </> "bin" </> f) requiredDlls)
    putStrLn (show fs)
    filterM doesFileExist fs

myPostCopy :: Args -> CopyFlags -> PackageDescription -> LocalBuildInfo -> IO ()
myPostCopy args copyFlags pd localBuildInfo = do
  (postCopy simpleUserHooks) args copyFlags pd localBuildInfo
  deps <- Bundle.depsWithData localBuildInfo
  extraFiles <- case buildOS of
                 Windows -> gatherWindowsExtraFiles
                 _ -> return []
  Bundle.postCopy Nothing extraFiles deps args copyFlags pd localBuildInfo

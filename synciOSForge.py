#Implement

#TODO: Scrypt that moves from forge to example, to test the whole plugin 
#Rename example to something else 
#Create a scryp that moves from plugin forge to media/ios/classes and rest of plugin class
#Maybe it will be one script with multiple options
#Create a proper example project, that uses the plugin directly 

import shutil
import os
from pathlib import Path
import argparse
import json


def copy_files_to_directory(file_list, destination_dir):
    """
    Copy files from a list to a specific directory.
    
    Args:
        file_list (list): List of file paths to copy
        destination_dir (str): Target directory path
    
    Returns:
        dict: Results with successful copies, failures, and skipped files
    """
    # Create destination directory if it doesn't exist
    dest_path = Path(destination_dir)
    dest_path.mkdir(parents=True, exist_ok=True)
    
    results = {
        'successful': [],
        'failed': [],
        'skipped': []
    }
    
    for file_path in file_list:
        source_path = Path(file_path)
        
        # Check if source file exists
        if not source_path.exists():
            results['failed'].append({
                'file': str(source_path),
                'error': 'File does not exist'
            })
            continue
        
        # Check if it's actually a file (not a directory)
        if not source_path.is_file():
            results['failed'].append({
                'file': str(source_path),
                'error': 'Path is not a file'
            })
            continue
        
        # Prepare destination path
        dest_file_path = dest_path / source_path.name
        
        try:
            # Check if file already exists in destination
            if dest_file_path.exists():
                print(f"Warning: {dest_file_path.name} already exists in destination.")
                response = input("Overwrite? (y/n/skip): ").lower().strip()
                
                if response == 'skip' or response == 's':
                    results['skipped'].append(str(source_path))
                    continue
                elif response != 'y' and response != 'yes':
                    results['skipped'].append(str(source_path))
                    continue
            
            # Copy the file
            shutil.copy2(source_path, dest_file_path)
            results['successful'].append({
                'source': str(source_path),
                'destination': str(dest_file_path)
            })
            print(f"✓ Copied: {source_path.name}")
            
        except PermissionError:
            results['failed'].append({
                'file': str(source_path),
                'error': 'Permission denied'
            })
        except shutil.SameFileError:
            results['failed'].append({
                'file': str(source_path),
                'error': 'Source and destination are the same file'
            })
        except Exception as e:
            results['failed'].append({
                'file': str(source_path),
                'error': str(e)
            })
    
    return results

pDirs = [
    'audio-forge',
    'plugin-forge',
    'example',
    'plugin'
    ]

filesMatrix = {
    'audio-forge' : ['AudioPlayer.swift','AudioPlayer+image.swift', 'Logger.swift'],
    'plugin-forge' : ['AudioPlayer.swift','AudioPlayer+image.swift', 
                      'AudioPlayerPlugin.swift', 'AudioPlayerWrapper.swift', 
                      'ThreadSafeDictionary.swift', 'Logger.swift'],
    'example' : ['AudioPlayer.swift','AudioPlayer+image.swift', 
                      'AudioPlayerPlugin.swift', 'AudioPlayerWrapper.swift', 
                      'ThreadSafeDictionary.swift', 'Logger.swift'],
    'plugin' : ['AudioPlayer.swift','AudioPlayer+image.swift', 
                      'AudioPlayerPlugin.swift', 'AudioPlayerWrapper.swift', 
                      'ThreadSafeDictionary.swift', 'Logger.swift']
}

pDirsPaths = {
    'audio-forge' : 'AudioPlayerForge/AudioPlayerForge',
    'plugin-forge' : 'plugin-forge/ios/Runner',
    'example' : 'TODO: Create this',
    'plugin' : 'ios/Classes'
}

###
# $ sync-ios-forge -s audio-forge -d plugin-forge
# $ sync-ios-forge -s plugin-forge -d example 
# $ sync-ios-forge -s plugin-forge -d plugin
def main():
    # Create the parser
    parser = argparse.ArgumentParser(
        description=f'This script is used to sync files between {pDirs} predefined directories.'
    )
    
    # Add arguments
    parser.add_argument(
        '-s', '--source',
        type=str,
        required=True,
        choices=pDirs,
        help=f"Source of the files"
    )
    
    parser.add_argument(
        '-d', '--destination',
        type=str,
        required=True,
        choices=pDirs,
        help=f'Destination for the files'
    )
    
    # Parse the arguments
    args = parser.parse_args()

    print(f"Starting to copy from {args.source} to {args.destination}...")

    srcDir = pDirsPaths[args.source]
    sourceFiles = filesMatrix[args.source]
    destDir = pDirsPaths[args.destination]
    destFiles = filesMatrix[args.destination]

    toCopyFiles = [file for file in sourceFiles if file in destFiles]
    
    sourceFiles = [os.path.join(srcDir, file) for file in toCopyFiles]

    res = copy_files_to_directory(sourceFiles, destDir)

    print(json.dumps(res, indent=2))

if __name__ == '__main__':
    main()
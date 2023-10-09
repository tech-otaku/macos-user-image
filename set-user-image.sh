#!/usr/bin/env bash

# AUTHOR: Steve Ward [steve at tech-otaku dot com]
# URL: https://github.com/tech-otaku/macos-user-image.git
# README: https://github.com/tech-otaku/macos-user-image/blob/main/README.md



# Ensure the `tidy_up` function is executed every time the script terminates regardless of exit status
    trap tidy_up EXIT



# # # # # # # # # # # # # # # # 
# FUNCTION DECLARATIONS
#

# Function to execute when the script terminates
    function tidy_up {
        rm -f $TF

        if [ ! -z $REVOKE ]; then
            sudo -k
        fi
    }

# Function to display usage help
    function usage {
        cat << EOF
                    
    Syntax: 
    ./$(basename $0) -h
    ./$(basename $0) -u USER_TO_UPDATE -i IMAGE_FILE [-p] [-r]

    Options:
    -h                      This help message.
    -i IMAGE_FILE           The image to use. Can be a full or relative path to the image. REQUIRED.
    -p                      Open the Users & Groups pane of System Settings/Preferences after the user's image has been changed.
    -r                      Revoke user's root privileges when script terminates.
    -u USER_TO_UPDATE       The user whose image to change. REQUIRED.
    
    Example: ./$(basename $0) -u miyuki -i images/giraffe.jpg -p -r
    
EOF
    }



# # # # # # # # # # # # # # # # 
# CONSTANTS 
# 

    # IMAGE_FILE = The image to use 
    # PREFS = Open the Users & Groups pane of System preferences after the users's image has been changed
    # REVOKE = Revoke user's root privileges when script terminates
    # USER_TO_UPDATE = The user whose image to change
    # TF = The import file to pass to `dsimport`
    # ER = End of record marker in the `dsimport` file
    # EC = Escape character in the `dsimport` file
    # FS = Field separator in the `dsimport`
    # VS = Value separator in the `dsimport` file

    unset IMAGE_FILE PREFS REVOKE USER_TO_UPDATE

    TF=$(mktemp)                                             
    ER=0x0A                 # `0x0A` (Hex) = `10` (ASCII) = `LF`
    EC=0x5C                 # `0x5C` (Hex) = `92` (ASCII) = `\`
    FS=0x3A                 # `0x3A` (Hex) = `58` (ASCII) = `:`
    VS=0x2C                 # `0x2C` (Hex) = `44` (ASCII) = `,`



# # # # # # # # # # # # # # # # 
# COMMAND LINE OPTIONS
#

# Exit with error if no command line options given
    if [[ ! $@ =~ ^\-.+ ]]; then
        printf "\nERROR: * * * No options given. * * *\n"
        usage
        exit 1
    fi

# Prevent an option that expects an argument, taking the next option as an argument if its argument is omitted. i.e. -u -i images/cow.jpg 
    while getopts ':hi:pru:' opt; do
        if [[ $OPTARG =~ ^\-.? ]]; then
            printf "\nERROR: * * * '%s' is not valid argument for option '-%s'\n" $OPTARG $opt
            usage
            exit 1
        fi
    done

# Reset OPTIND so getopts can be called a second time
    OPTIND=1

# Process command line options
    while getopts ':hi:pru:' opt; do
        case $opt in
            h)
                usage
                exit 0
                ;;
            i) 
                IMAGE_FILE=$OPTARG 
                ;;
            p) 
                PREFS=true 
                ;;
            r) 
                REVOKE=true 
                ;;
            u) 
                USER_TO_UPDATE=$OPTARG 
                ;;
            :) 
                printf "\nERROR: * * * Argument missing from '-%s' option * * *\n" $OPTARG
                usage
                exit 1
                ;;
            ?) 
                printf "\nERROR: * * * Invalid option: '-%s'\n * * * " $OPTARG
                usage
                exit 1
                ;;
        esac
    done



# # # # # # # # # # # # # # # # 
# USAGE CHECKS
#

# Image to use
    if [ -z "$IMAGE_FILE" ]; then
        printf "\nERROR: * * * No image was specified. * * *\n"
        usage
        exit 1
    elif [ ! -f "$IMAGE_FILE" ]; then 
        printf "\nERROR: * * * Image file '%s' doesn't exist. * * *\n" "$IMAGE_FILE"
        exit 1
    fi

# User whose image to change
    if [ -z $USER_TO_UPDATE ]; then
        printf "\nERROR: * * * No user was specified. * * *\n"
        usage
        exit 1
    elif ! id -u $USER_TO_UPDATE >/dev/null 2>&1; then 
        printf "\nERROR: * * * User '%s' doesn't exist.* * *\n" "$USER_TO_UPDATE"
        exit 1
    fi



# # # # # # # # # # # # # # # # 
# SET-UP
#

# Authenticate user upfront
    sudo -v

# Quit System Settings (previously System Preferences prior to macOS Ventura 13)
    SETTINGS="System Settings"
    if [[ $(system_profiler SPSoftwareDataType | awk '/System Version/ {print $4}' | cut -d . -f 1) -lt 13 ]]; then
        SETTINGS="System Preferences"
    fi

    killall "$SETTINGS" 2> /dev/null                        # Write STDERR to /dev/null to supress message if process isn't running



# # # # # # # # # # # # # # # # 
# UPDATE USER IMAGE
#

# Write a record description (header line) to the import file
    echo "$ER $EC $FS $VS dsRecTypeStandard:Users 2 RecordName externalbinary:JPEGPhoto" > $TF

# Write the record to the import file
    echo "$USER_TO_UPDATE:$IMAGE_FILE" >> $TF

# Delete the existing `JPEGPhoto` attribute for the user 
    sudo dscl . delete /Users/$USER_TO_UPDATE JPEGPhoto

# Import the record updating the `JPEGPhoto` attribute for the user
    sudo dsimport $TF /Local/Default M



# # # # # # # # # # # # # # # # 
# FINISH UP
#

# Optionally open the Users & Groups pane of System Settings (previously System Preferences prior to macOS Ventura 13)
    if [ ! -z $PREFS ]; then
    # All 3 of the commands below achieve the same thing and work with System Settings and System Preferences
        open /System/Library/PreferencePanes/Accounts.prefPane
#        open "x-apple.systempreferences:com.apple.preferences.users"
#        open "x-apple.systempreferences:com.apple.Users-Groups-Settings.extension"
    fi
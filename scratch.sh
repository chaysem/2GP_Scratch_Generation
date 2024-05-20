#!/bin/bash

# Dependencies (init)
init_package_deps() {
    packages=()
    while IFS= read -r package; do
    if [[ $package == *"@"* ]]; then
        id=$(awk -F: '/'$package'/ {gsub(/ /, "", $2); gsub(/"/, "", $2); print $2}' sfdx-project.json)
        if [[ -z "$id" ]]; then
            continue
        else
            packages+=("$(echo $id | tr -d ',' | grep -oE '04t.*')")
        fi
    elif [[ $package == 04t* ]]; then
        packages+=("$(echo $package | tr -d ',' | grep -oE '04t.*')")
    fi
    done <<< "$(awk -F: '/"package"/ || /"subscriberPackageVersionId"/ {gsub(/ /, "", $2); gsub(/"/, "", $2); print $2}' sfdx-project.json | tr ',' '\n')"
}

# Defaults
init() {
    root=$(pwd)
    scratchName=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    days=30
    scratchDef="Y"
    deploySource="Y"

    # Devhub -- default to active -- otherwise first connected
    devhub=$(sf org list 2>/dev/null | grep "DevHub " | grep "Connected" | awk 'NF>1 && $2 !~ /@/ {print $0}' | grep "🌳" | awk '{print $3}' | head -n 1)
    if [ -z "$devhub" ]; then
        devhub=$(sf org list 2>/dev/null | tr -d '🌳' | grep "DevHub " | grep "Connected" | awk 'NF>1 && $2 !~ /@/ {print $2}' | head -n 1)
    fi

    init_package_deps
}

print_config() {
    clear
    printf "                                                        SCRATCH ORG GENERATOR\n"
    printf "______________________________________________________________________________________________________________________________\n"
    printf "|\t\t\t\t\t\t\t\t |\n"
    printf "| CONFIG / COMMANDS\t\t\t\t\t\t |\n"
    printf "| (1) Project Root Directory:\t\t\t\t\t | $root\n"
    printf "| (2) Scratch Org Name:\t\t\t\t\t\t | $scratchName\n"
    printf "| (3) Number of Days:\t\t\t\t\t\t | $days\n"
    printf "| (4) Devhub Alias:\t\t\t\t\t\t | $devhub\n"
    printf "| (5) Use "config/project-scratch-def.json" (Y/N):\t\t | $scratchDef\n"
    printf "| (6) Deploy Source After Creation (Y/N):\t\t\t | $deploySource\n"
    printf "| (7) Package Dependencies (installed in order):\t\t | \n"
    printf "|\t\t\t\t\t\t\t\t |\n"
    index=1
    for package in "${packages[@]}"; do
        printf "|\t\t\t\t\t\t\t\t | ($index) $package\n"
        index=$((index + 1))
    done

    printf "|\t\t\t\t\t\t\t\t |\n"
    printf "| (C) Create Scratch Org\t\t\t\t\t |\n"
    printf "______________________________________________________________________________________________________________________________\n\n"
}

project_root_directory() {
    read -p "Project Root Directory (Press Enter for Default: $(pwd)): " root
    root=${root:-$(pwd)}
}

scratch_org_name() {
    while true; do
        read -p "Scratch Org Name: " scratchName
        if [[ -z "$scratchName" ]]; then
            echo "Scratch Org Name cannot be empty. Please enter again."
        else
            break
        fi
    done
}

number_of_days() {
    while true; do
        read -p "Number of Days (1-30): " days
        if [[ "$days" =~ ^[1-9]$|^1[0-9]$|^2[0-9]$|^30$ ]]; then
            break
        else
            echo "Invalid input. Please enter a number between 1 and 30."
        fi
    done

}

devhub_alias() {

    # Select a connected devhub
    devhub_list=()
    while IFS= read -r line; do
        devhub_list+=("$line")
    done < <(sf org list 2>/dev/null | tr -d '🌳' | grep "DevHub " | grep "Connected" | awk 'NF>1 && $2 !~ /@/ {print $2}')

    if [ ${#devhub_list[@]} -eq 0 ]; then
        printf "No connected devhubs found. Please connect to a devhub first.\n"
        exit 1
    fi

    # Loop the devhubs as a numeric list of options
    printf "ACTIVE CONNECTED DEVHUBS\n"
    index=1
    for devhub in "${devhub_list[@]}"; do
        printf "($index) $devhub\n"
        index=$((index + 1))
    done

    # Select a devhub
    printf "\n"
    while true; do
        read -p "Select a Devhub (1-${#devhub_list[@]}): " index
        if [[ "$index" =~ ^[1-9]$|^1[0-9]$|^2[0-9]$ ]]; then
            devhub=${devhub_list[$index-1]}
            break
        else
            echo "Invalid input. Please enter a number between 1 and ${#devhub_list[@]}."
        fi
    done
}

scratch_def() {
    while true; do
        read -p "Use "config/project-scratch-def.json" (Y/N): " scratchDef
        if [[ "$scratchDef" =~ ^[Yy]$ ]]; then
            scratchDef="Y"
            break
        elif [[ "$scratchDef" =~ ^[Nn]$ ]]; then
            scratchDef="N"
            break
        else
            echo "Invalid input. Please enter Y or N."
        fi
    done
}

deploy_source() {
    while true; do
        read -p "Deploy Source After Creation (Y/N): " deploySource
        if [[ "$deploySource" =~ ^[Yy]$ ]]; then
            deploySource="Y"
            break
        elif [[ "$deploySource" =~ ^[Nn]$ ]]; then
            deploySource="N"
            break
        else
            echo "Invalid input. Please enter Y or N."
        fi
    done
}

manage_packages() {
    while true; do
        read -p "Enter your choice (C)lear, (A)dd, (R)emove, (B)ack: " choice
        case $choice in
            [Cc]* )
                packages=()
                echo "All packages have been cleared."
                ;;
            [Aa]* )
                read -p "Enter the package to add: " package
                packages+=("$package")
                echo "Package $package has been added."
                ;;
            [Rr]* )
                read -p "Enter the index of the package to remove: " index
                if [[ $index -ge 1 ]] && [[ $index -le ${#packages[@]} ]]; then
                    package_removed=${packages[$index-1]}
                    packages=("${packages[@]:0:$((index-1))}" "${packages[@]:$index}")
                    echo "Package $package_removed has been removed."
                else
                    echo "Invalid index. No package removed."
                fi
                ;;
            [Bb]* )
                break
                ;;
            * )
                echo "Please enter C, A, R, or B."
                ;;
        esac
    done
}

create_scratch_org() {
    read -p "Are you sure you want to proceed? (y/n) " -n 1 -r
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo "Operation cancelled by user."
        return 1
    fi

    cd $root

    # Generate the org
    if [[ "$scratchDef" == "Y" ]]; then
        sf org create scratch -a $scratchName -y $days -w99 -e developer -d -v $devhub
    else
        sf org create scratch -a $scratchName -y $days -w99 -e developer -d -f config/project-scratch-def.json -v $devhub
    fi

    # Install any package dependencies
    if [ ${#packages[@]} -ne 0 ]; then
        echo "Installing Packages ..."
        printf -v joined '%s,' "${packages[@]}"
        echo "${joined%,}"
        for pkg in ${packages[@]}; do
            sf package install -p $pkg -w99 -r -s "AllUsers" -r
        done
    fi

    # Deploy source
    if [[ "$deploySource" == "Y" ]]; then
        sf project deploy start -w99
    fi
}

# Main
init
while true; do
    print_config
    read -p "Enter your choice: " choice
    case $choice in
        1)
            print_config
            project_root_directory
            ;;
        2)
            print_config
            scratch_org_name
            ;;
        3)
            print_config
            number_of_days
            ;;
        4)
            print_config
            devhub_alias
            ;;
        5)
            print_config
            scratch_def
            ;;
        6)
            print_config
            deploy_source
            ;;

        7)
            print_config
            manage_packages
            ;;
        C|c)
            print_config
            create_scratch_org
            break
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
done

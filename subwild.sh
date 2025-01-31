#!/bin/bash

RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

# Prompt the user for the file containing domain names
read -p "Enter the domain list file path: " domain_list_file

# Check if the file exists
if [ ! -f "$domain_list_file" ]; then
    echo -e "${RED}File not found! Exiting...${ENDCOLOR}"
    exit 1
fi

# Define the final output file for all subdomains
final_output="final_subdomains.txt"
> "$final_output"  # Clear the file before starting

# Loop over each domain in the file
while IFS= read -r subdomain; do
    # Skip empty lines or comments in the domain list file
    if [[ -z "$subdomain" || "$subdomain" =~ ^# ]]; then
        continue
    fi

    echo -e "${GREEN}Processing domain: $subdomain${ENDCOLOR}"
    
    # Create a directory for each domain's output
    mkdir -p "$subdomain"_output
    cd "$subdomain"_output || exit

    # Subfinder
    subfinder -d "$subdomain" | tee subdomains

    # AssetFinder
    echo -e "${RED}AssetFinder Running .........${ENDCOLOR}"
    assetfinder -subs-only "$subdomain" | tee -a subdomains

    # Collecting subdomains from cert.sh
    echo -e "${GREEN}Collecting Subdomains from cert.sh.........${ENDCOLOR}"
    curl -s "https://crt.sh/?q=%25.$subdomain" | grep -oE "[a-zA-Z0-9._-]+\.$subdomain" | sort -u | tee -a subdomains

    # Collecting subdomains from Wayback Machine
    echo -e "${GREEN}Collecting Subdomains from Wayback Machine.......${ENDCOLOR}"
    curl -s "http://web.archive.org/cdx/search/cdx?url=*.$subdomain&output=text&fl=original&collapse=urlkey" | sed -e 's_https*://__' -e "s/\/.*//" | sort -u | tee -a subdomains

    # Collecting subdomains from VirusTotal
    echo -e "${GREEN}Collecting Subdomains from VirusTotal.......${ENDCOLOR}"
    curl -s "https://www.virustotal.com/vtapi/v2/domain/report?apikey=b203b63fbefe6451201afb3e4e313c47e0705bedcdcdf118ba687d5239f732a6&domain=$subdomain" | jq -r '.subdomains[]' | tee -a subdomains

    # Subenum
    echo -e "${GREEN}Running Subenum.......${ENDCOLOR}"
    subenum.sh -d "$subdomain" -o out

    # DNS Subdomain brute forcing (example)
    echo "DNS Subdomain Gathering....."
    # Uncomment below if you want to use gobuster
    # gobuster dns -d "$subdomain" -w /path/to/wordlist -o dns_sub -t 200 --wildcard

    # Collecting DNS subdomains (example output)
    cat dns_sub | grep -oP '(?<=Found: )[^.]+\.[^.]+\.[^.]+' | tee dns

    # Combine all subdomain results for this domain
    cat dns subdomains out | sort -u | tee all_subs
    rm -rf dns_sub

    # Subjack for subdomain takeover
    subjack -w all_subs -v | tee subjack_out

    # HTTPx to check live subdomains
    cat all_subs | httpx | tee subs

    # Append subdomains to the final output file
    cat subs >> "../$final_output"

    # Cleanup
    rm all_subs

    # Return to the original directory
    cd ..
    
    echo -e "${GREEN}Finished processing domain: $subdomain${ENDCOLOR}"

done < "$domain_list_file"

# Remove duplicates from the final subdomains file
sort -u "$final_output" -o "$final_output"

echo -e "${GREEN}All subdomains saved in: $final_output${ENDCOLOR}"

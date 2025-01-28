input_file="$1"          # First argument: Input file containing URLs
output_file="pdf-juicy"  # Fixed output file name

if [ -z "$input_file" ] || [ ! -f "$input_file" ]; then
    echo "Error: Please provide a valid input file containing URLs." >&2
    exit 1
fi

grep -Eai '\.pdf' "$input_file" | xargs -I {} -P 5 sh -c '
    url="{}"
    response=$(curl -sf "$url")
    
    if [ -z "$response" ]; then
        echo "No response or empty content for $url" >&2
        exit 1
    fi

    # Check if the response is a PDF document using `file`
    if echo "$response" | file - | grep -iq "PDF document"; then
        # Try extracting text and check for sensitive keywords
        if echo "$response" | pdftotext - - 2>/dev/null | grep -Eaiq "(internal use only|confidential|strictly private|personal & confidential|private|restricted|internal|not for distribution|do not share|proprietary|trade secret|classified|sensitive|bank statement|invoice|salary|contract|agreement|non disclosure|passport|social security|ssn|date of birth|credit card|identity|id number|company confidential|staff only|management only|internal only)"; then
            echo "$url" | tee -a '"$output_file"'
        else
            echo "No sensitive data found in $url" >&2
        fi
    else
        echo "Skipping non-PDF file: $url" >&2
    fi
'
echo "Total valid URLs saved: $(wc -l < "$output_file")"

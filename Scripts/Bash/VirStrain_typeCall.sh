#!/bin/bash
set -e
set -u

# VirStrain subtyping
# define help function
function help ()
{
	printf "Usage: %s: some var is missing 
	[-h|--help]\n" "$(basename "$0")" >&2
    exit
}

# Reading input parameters
while [[ "$#" -gt 0 ]]; do
	case "$1" in
		-f|--fastqaddr) FQAddr="$2"; [ "$(echo "$2" | cut -c 1)" == "-" ] || [ "$2" == "" ] && help || shift 2;;
		-s|--TopRunName) TopRunName="$2"; [ "$(echo "$2" | cut -c 1)" == "-" ] || [ "$2" == "" ] && help || shift 2;;
        -m|--mainf) MainF="$2"; [ "$(echo "$2" | cut -c 1)" == "-" ] || [ "$2" == "" ] && help || shift 2;;
        -v|--virdb) VirStrain_db="$2"; [ "$(echo "$2" | cut -c 1)" == "-" ] || [ "$2" == "" ] && help || shift 2;;
        -c|--prevcall) prevCall="$2"; [ "$(echo "$2" | cut -c 1)" == "-" ] || [ "$2" == "" ] && help || shift 2;;
        -t|--typetier) typeTier="$2"; [ "$(echo "$2" | cut -c 1)" == "-" ] || [ "$2" == "" ] && help || shift 2;;
        -g|--typetop) typeTop="$2"; [ "$(echo "$2" | cut -c 1)" == "-" ] || [ "$2" == "" ] && help || shift 2;;
        -r|--typerank) typeRank="$2"; [ "$(echo "$2" | cut -c 1)" == "-" ] || [ "$2" == "" ] && help || shift 2;;
        -h|--help) help;;
        *) help;;
    esac
done

#  Define Folders and params
FQName=$(basename $FQAddr .fastq)
GenoOut=$MainF/Results/$TopRunName/$FQName/TypeCalls

# Set names depending on typerank being declared
if [[ -v typeRank ]]
then
    mkdir -p $MainF/Results/$TopRunName/$FQName/TypeCalls/Details_T${typeTier}_R${typeRank}
    VirSOut=$MainF/Results/$TopRunName/$FQName/TypeCalls/Details_T${typeTier}_R${typeRank}
    mergedOut=$GenoOut/${FQName}_T${typeTier}_R${typeRank}.txt
    splitOut=$GenoOut/${FQName}_T${typeTier}_R${typeRank}_SplitTo.txt
    virOutFile=$VirSOut/SubtypeCall_T${typeTier}_R${typeRank}.txt
else
    mkdir -p $MainF/Results/$TopRunName/$FQName/TypeCalls/Details_T${typeTier}
    VirSOut=$MainF/Results/$TopRunName/$FQName/TypeCalls/Details_T${typeTier}
    mergedOut=$GenoOut/${FQName}_T${typeTier}.txt
    splitOut=$GenoOut/${FQName}_T${typeTier}_SplitTo.txt
    virOutFile=$VirSOut/SubtypeCall_T${typeTier}.txt
fi

# Call types with VirStrain
cd ~/VirStrain
python /home/pato/VirStrain/VirStrain.py -i $FQAddr -d $VirStrain_db -o $VirSOut -s 1
cd

# Print top n, if VirStrain found anything
if [ -f ${VirSOut}/VirStrain_report.txt ];
then

    for (( lineN=1; lineN<=$typeTop; lineN++ ))
    do 
        grabLine=$(expr $lineN + 1) #  (1. line is header in report)
        foundType="$(grep -A10 Top10_Score_Strains ${VirSOut}/VirStrain_report.txt | awk -v a=$grabLine 'FNR == a {print $1}' | awk 'sub(/^>/, "")')"
        mapScore="$(grep -A10 Top10_Score_Strains ${VirSOut}/VirStrain_report.txt | awk -v a=$grabLine 'FNR == a {print $4}')"
        roundMapScore="$(echo "$mapScore" | xargs printf "%.*f\n" 5)"
        siteCov="$(grep -A10 Top10_Score_Strains ${VirSOut}/VirStrain_report.txt | awk -v a=$grabLine 'FNR == a {print $5}')"

        echo $foundType >> $virOutFile
        echo $foundType >> $splitOut
        echo $foundType "("$roundMapScore")("$siteCov")" >> ${virOutFile%.txt}_wScore.txt

        # also sending to file where they are merged to one line by '_'
        if [ -f $mergedOut ]
        then
            old=$(awk 'FNR == 1 {print $1}' $mergedOut)
            echo "$old"_"$foundType" > $mergedOut
        else
            echo $foundType > $mergedOut
        fi

    done
else
    varCheck() {
        # Checks if variable is defined. If, set subtype to genotype, else skips loop 
        if [ -n "${prevCall-}" ]
        then
            echo $prevCall > $mergedOut
            echo $prevCall > $splitOut
            echo $prevCall > $virOutFile
            echo $prevCall "(No Subtype found)" > ${virOutFile%.txt}_wScore.txt
        elif [ "${prevCall+defined}" = defined ]
        then
            echo "$FQName - No genotype found" >> $MainF/Results/$TopRunName/Not_genotyped.txt
        else
            echo "$FQName - No genotype found" >> $MainF/Results/$TopRunName/Not_genotyped.txt
        fi
    }
    varCheck
fi

# Save outputs to summary. If typeRank, add the virstrain_db name (it's the overtype)
if [[ -v typeRank ]]
then
    BaseDBName=$(basename $VirStrain_db _VirStrainDB)
    echo -e $FQName '\t' $BaseDBName '\t' "$(mapfile -t < ${virOutFile%.txt}_wScore.txt; printf '%s\t' "${MAPFILE[@]}")" >> $MainF/Results/$TopRunName/TypeCallSummary_T${typeTier}.txt
else
    echo -e $FQName '\t' "$(mapfile -t < ${virOutFile%.txt}_wScore.txt; printf '%s\t' "${MAPFILE[@]}")" >> $MainF/Results/$TopRunName/TypeCallSummary_T${typeTier}.txt
fi


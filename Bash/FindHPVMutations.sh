#!/bin/bash

# set -e
# set -u
# set -x
# set -o pipefail

# Genererer custom referencer efter genotype calls, hvis der er flere HPV typer i en prøve. De vakgte


# Henter options
Options=$(grep -v "^-" /home/pato/Skrivebord/HPV16_projekt/FindHPVMutations_options.txt)

Name=$(grep "RunName=" <<< $Options | sed 's/RunName=//g')
MainF=$(grep "MainF=" <<< $Options | sed 's/MainF=//g')
QualTrim=$(grep "QualTrim=" <<< $Options | sed 's/QualTrim=//g')
MinLen=$(grep "MinLen=" <<< $Options | sed 's/MinLen=//g')
MaxLen=$(grep "MaxLen=" <<< $Options | sed 's/MaxLen=//g')
AmpliconRef=$(grep "AmpliconRef=" <<< $Options | sed 's/AmpliconRef=//g')
BedFileNameX=$(grep "BedFileNameX=" <<< $Options | sed 's/BedFileNameX=//g')



########## Scripts to use ##########
customRefForAll=$(grep "customRefForAll=" <<< $Options | sed 's/customRefForAll=//g')
cRef=$(grep "cRef=" <<< $Options | sed 's/cRef=//g') 
customName=$(grep "customName=" <<< $Options | sed 's/customName=//g') 
cName=$(grep "cName=" <<< $Options | sed 's/cName=//g')
indexReferences=$(grep "indexReferences=" <<< $Options | sed 's/indexReferences=//g')
cutOutsideAmplicons=$(grep "cutOutsideAmplicons=" <<< $Options | sed 's/cutOutsideAmplicons=//g') # Risk of loosing data if HPV is other type than the one used in ampliconpanel
qualityFilt=$(grep "qualityFilt=" <<< $Options | sed 's/qualityFilt=//g') # Skal ligenu være true, ellers skal fastqfiler gives endelsen "_filt.fastq" for at senere moduler kan finde dem
CombineRefs=$(grep "CombineRefs=" <<< $Options | sed 's/CombineRefs=//g')
AlignAndVarCall=$(grep "AlignAndVarCall=" <<< $Options | sed 's/AlignAndVarCall=//g')
RunAnnoRSCript=$(grep "RunAnnoRSCript=" <<< $Options | sed 's/RunAnnoRSCript=//g')
RunSiteCovScript=$(grep "RunSiteCovScript=" <<< $Options | sed 's/RunSiteCovScript=//g')
RunNoCallsScript=$(grep "RunNoCallsScript=" <<< $Options | sed 's/RunNoCallsScript=//g')
VirStrainGenoAndSubTyping=$(grep "VirStrainGenoAndSubTyping=" <<< $Options | sed 's/VirStrainGenoAndSubTyping=//g') 
VirStrainMaindb=$(grep "VirStrainMaindb=" <<< $Options | sed 's/VirStrainMaindb=//g') 
VirStrainSubFolders=$(grep "VirStrainSubFolders=" <<< $Options | sed 's/VirStrainSubFolders=//g') 
E4SpliceCalls=$(grep "E4SpliceCalls=" <<< $Options | sed 's/E4SpliceCalls=//g') 
####################################

#Test
#Name=Magnus1
#MainF=/home/pato/Skrivebord/HPV16_projekt
#QualTrim=20
#MinLen=50
#MaxLen=320
#AmpliconRef=K02718.1
#BedFileNameX=IAD209923_226_Designed_compl
#
#customRefForAll=false
#
#customName=false 
#cName=Karoline_run_covGenTest_1207_08072021
#indexReferences=false
#cutOutsideAmplicons=false # Kan risiskere at miste data hvis HPV er andre typer end den brugt til at lave ampliconpanel
#qualityFilt=true
#CombineRefs=true
#AlignAndVarCall=true
#SplitAndVarCall=true
#RunAnnoRSCript=true
#RunSiteCovScript=true
#RunNoCallsScript=true
#VirStrainGenoAndSubTyping=false # Se nedenstående info
#VirStrainMaindb=Combined_mainlines_wRevised_wHPV-mTypes
#VirStrainSubFolders=VirStrainDBs_HPV_sub



# Gå til MainF og opret mappe med samme navn som RunName, eks: 
mkdir -p $MainF/{GenotypeCalls,References/{IndexedRef,Combined_refs},Results/$SuperRunName/,ReferenceDetails,FASTQ,Analysis/{Qual,Depth,Flagstats,DuplicateMetrics,Errors}} # -p option enables returning no error if folders exist. They will not be overwritten either way. 

SeqF=$MainF/FASTQ; AnaF=$MainF/Analysis; QualF=$AnaF/Qual; DepthF=$AnaF/Depth; FlagF=$AnaF/Flagstats;
DupF=$AnaF/DuplicateMetrics; RefdF=$MainF/ReferenceDetails; RefF=$MainF/References; ErrorF=$AnaF/Errors; InputRefs=$RefF/InputRefs

rm -f $RefF/*fasta.fai

if [ $customName = true ]; then

	SuperRunName=$(grep "cName=" <<< $Options | sed 's/cName=//g') 
	echo "Using custom name and saved reference info..."

else

	# Date= # Uncomment til testfiler og comment næste linje
	Date=$(date +"%H%M_%d%m%Y")
	SuperRunName=$(echo ${Name}_${Date})

	FastQF=$MainF/FASTQ
	find $FastQF/ -maxdepth 1  -name '*.fastq' | sed 's/^.*FASTQ.//' | sed 's/.fastq//' \
	> $MainF/FASTQfiles_${SuperRunName}.txt #Finder FASTQ filer i FASTQ mappe og laver tekstfil med alle navne 
	find $FastQF/ -maxdepth 1  -name '*.fastq' | sed 's/^.*FASTQ.//' | sed 's/.fastq//' | sed 's/$/_run/' \
	> $MainF/FASTQfiles_${SuperRunName}_runnames.txt # Laver fastqnavne til RunName variabel  (så den er anderledes en navnet)

	echo Appending time and date to name
fi

Rscriptfolder=$MainF/Scripts/R
MultiFQFile=$(echo FASTQfiles_$SuperRunName)
ResultsF=$MainF/Results/$SuperRunName

####################################

FastqList=$(< $MainF/FASTQfiles_${SuperRunName}.txt) # Henter liste og gemmer som variabel
FastqRunList=$(< $MainF/FASTQfiles_${SuperRunName}_runnames.txt)

########################## Primer sekvens cut #########################
if [ $cutOutsideAmplicons = true ]; then
	
	START=1
	END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)

	for (( linenumber=$START; linenumber<=$END; linenumber++ )); do
	FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
	FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 	
	PrimerSeqCut.sh
 	done
 	
fi

############################# FASTQ FILTRERING ###############################
if [ $qualityFilt = true ]; then

START=1
END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)
	for (( linenumber=$START; linenumber<=$END; linenumber++ )); do

	FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
	FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 
	FastqInputAddr=$SeqF/${FastqInput}.fastq
	cutadapt -q $QualTrim -m $MinLen -M $MaxLen ${FastqInputAddr} -o ${FastqInputAddr%.fastq}_filt.fastq
	
	done

fi
# Dette navngiver filer med endelsen "_filt.fastq", hvilket er et krav for at resten af workflowet kan finde fastq filerne
##############################################################################
# Output: _filt.fastq filer

####### REFERENCE INDEXERING TIL ALIGNMENT OG VARIANTCALLING ##########
# Putter hver reference i en undermappe for sig, så de er klar til kørsel
# genererer også dict fil og samtools faidx fil til HaplotypeCaller
# Genererer index til bwa mem
if [ $indexReferences = true ]; then

for f in $RefF/*.fasta; do

	RefName=${f##*/}
	mkdir -p $RefF/IndexedRef/${RefName%.fasta}

	#Checker om fasta fil ligger i index mappe
	if [ -f $RefF/IndexedRef/${RefName%.fasta}/${RefName} ]; then
	echo $RefName already in IndexedRef folder
	else

	cp $f $RefF/IndexedRef/${RefName%.fasta}/$RefName
	Ref_FASTA=$RefF/IndexedRef/${RefName%.fasta}/$RefName

	samtools faidx $Ref_FASTA
	
	# Create sequence dictionary for gatk haplotypecaller
	java -jar picard.jar CreateSequenceDictionary \
	R=$Ref_FASTA \
	O=${Ref_FASTA%.fasta}.dict 2> $ErrorF/CreateSequenceDictionary_errors_${refType}.txt
	
	# Create index for bwa mem
	bwa index $Ref_FASTA
	fi

done

fi
########################################################################

# Laver InputRefs filer for alle fastq filer hvis de er brugerdefineret som ens for alle fastq filer
if [ $customRefForAll = true ]; then
	START=1
	END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)
	for (( linenumber=$START; linenumber<=$END; linenumber++ )); do
	FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
	FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 
	
	rm -f $MainF/References/InputRefs/${FastqInput}.txt
	touch $MainF/References/InputRefs/${FastqInput}.txt
	
	for newref in ${cRef[@]}; do
	echo $newref >> $MainF/References/InputRefs/${FastqInput}.txt
	done
	done
fi



############## LAVER KOMBINEREDE REFERENCER OG/ELLER GEMMER VALGTE REFERENCER I GENOTYPECALLS MAPPE #########################
mkdir -p $MainF/GenotypeCalls/$SuperRunName
if [ $CombineRefs = true ] && [ $VirStrainGenoAndSubTyping = false ]; then
START=1
END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)
for (( linenumber=$START; linenumber<=$END; linenumber++ )); do


FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 
FastqInputAddr=$SeqF/${FastqInput}.fastq



# Finder antal referencer i referencefil
RefNumber=$(wc -l $InputRefs/${FastqInput}.txt | awk '{ print $1 }')

# Hvis mere end 1 type i prøve, laver kombinerede referencefiler (fasta) og gemmer info i Genotypecalls mappe
if [ $RefNumber -gt 1 ]; then

	# Læser referencer som array
	readarray -t RefsArr < $InputRefs/${FastqInput}.txt

	# Initerer array
	declare -a AllAddressList="" 

	rm -f $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}_SplitTo.txt
	for ref in ${RefsArr[@]}; do
	
	AllAddressList+=" "
	AllAddressList+=$( find $RefF -maxdepth 1  -name "${ref}*" -type f )
	echo "${ref}" >> $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}_SplitTo.txt

	done

	# Laver nyt fasta navn for kombineret reference
	newRefName=$(printf "_%s" "${RefsArr[@]}")
	newRefName=${newRefName:1} # Fjerner forkert foranstående "_" der opstår i ovenstående
	newRefNameFasta=${newRefName}.fasta

	# Send refname til fundne referencer for fil 
	echo $newRefName > $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}.txt

	# Har nu adresser til pågældende referencer. Samler:
	cat $AllAddressList > $RefF/Combined_refs/$newRefNameFasta


	# INDEXERER OG LÆGGER I IndexedRefs MAPPE
	NewRef=$RefF/Combined_refs/$newRefNameFasta
	RefName=${NewRef##*/}
	mkdir -p $RefF/IndexedRef/${RefName%.fasta}
	cp $NewRef $RefF/IndexedRef/${RefName%.fasta}/$RefName
	Ref_FASTA=$RefF/IndexedRef/${RefName%.fasta}/$RefName

	# Create sequence dictionary for gatk haplotypecaller
	java -jar picard.jar CreateSequenceDictionary \
	R=$Ref_FASTA \
	O=${Ref_FASTA%.fasta}.dict 2> $ErrorF/CreateSequenceDictionary_errors_${RefName}.txt

	# Create index for bwa mem
	bwa index $Ref_FASTA

	# Index with samtools faidx
	samtools faidx $Ref_FASTA



else
# Ellers hvis der kun er en type i fastq fil, gem da referencenavn i variabel fra txt fil og putter ud i GenotypeCalls mappe til efterfølgende programmer
	Ref_FASTA=$(< $InputRefs/${FastqInput}.txt)
	echo "${Ref_FASTA}" > $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}.txt
	echo "${Ref_FASTA}" > $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}_SplitTo.txt

fi 

done
elif [ $CombineRefs = false ] && [ $VirStrainGenoAndSubTyping = false ] && [ $customName = false ]; then

	# Ellers hvis der ikke skal kombineres referencer, gem da referencenavne fra inputrefs i genotypecalls
	START=1
	END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)
	for (( linenumber=$START; linenumber<=$END; linenumber++ )); do
	FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
	FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 

	rm -f $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}.txt
	touch $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}.txt

	rm -f $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}_SplitTo.txt
	touch $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}_SplitTo.txt

	for newref in ${cRef[@]}; do
	echo $newref >> $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}.txt
	echo $newref >> $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}_SplitTo.txt
	done
	done

fi

###############################################################################################
# Output: $MainF/GenotypeCalls/${SuperRunName}/${FastqInput}.txt 	og _SplitTo.txt version
# medmindre VirStrainGenoAndSubTyping er true og combineRefs er false, hvortil ingenting outputtes. 


############################# MAIN GENOTYPING & SUBTYPING ###############################
if [ $VirStrainGenoAndSubTyping = true ]; then
# Finder ligenu top 3 most possible strains
conda init bash
conda activate VarStrain # VirStrain har meget specifikke krav til pakke versioner, derfor køres conda env

VSdb=$MainF/References/$VirStrainMaindb
START=1
END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)

for (( linenumber=$START; linenumber<=$END; linenumber++ ))
do
	FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
	FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 
	VirStrain_genotyping.sh $FastqRunInput $FastqInput $SuperRunName $MainF $VSdb
	echo $linenumber of $END
done


# SUBTYPING
START=1
END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)

for (( linenumber=$START; linenumber<=$END; linenumber++ ))
do

	#TEST
	#linenumber=1
	FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
	FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 
	
	# Finder kaldt maintype og henter korrekt VirStrain subtypedatabase
	SuperRunOut=$MainF/VirStrain_run/$SuperRunName/Genotypecalls
	Resultsout=$SuperRunOut/$FastqRunInput
	
	MainCallFile=$Resultsout/SubtypeCall.txt
	VirStrainSub=$(grep -m1 -o "^HPV[0-9]*" $MainCallFile) # -m1 for kun at søge første linje og -o for kun at output match og ikke hele linje med match
	MainCallFullName=$(grep -m1 "^HPV[0-9]*" $MainCallFile)
	BaseDBName=$(echo ${VirStrainSub}_VirStrainDB)
	VirStrainSubDB=$MainF/References/$VirStrainSubFolders/$BaseDBName


	VirStrain_genotypeToSubtype.sh $FastqRunInput $FastqInput $SuperRunName $MainF $VirStrainSubDB $VirStrainSub $MainCallFullName
	echo $linenumber of $END

done

conda deactivate
fi

#######################################################################
# Output: $MainF/GenotypeCalls/$SuperRunName/${FastQFile}.txt 	og _SplitTo.txt version
# Begge med en enkelt reference og ikke flere referencer







################## MULTIPLE TYPES AWARE ALIGNMENT & VARIANT CALLING ###########################
# Input: Referencer fra $MainF/GenotypeCalls/$SuperRunName/${FastQFile}.txt, sammen med fastqfiler
if [ $AlignAndVarCall = true ]; then 
# Bruger _filt.fastq filer fra filtrering og referencekald. 

START=1
END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)
for (( linenumber=$START; linenumber<=$END; linenumber++ ))
do

	FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
	FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 
	GenoTypeCallIn=$MainF/GenotypeCalls/$SuperRunName
	AlignAndVariantCall.sh $FastqRunInput $FastqInput $SuperRunName $MainF $GenoTypeCallIn $BedFileNameX $AmpliconRef
	echo fil $FastqInput færdig med alignment og variantcalling... $linenumber af $END fastqfiler

done
fi
################################################################################################

if [ $VirStrainGenoAndSubTyping = true ]; then

# Flytter filer rundt for convenience, hvis der har været subtyperet
	FILE1=$MainF/VirStrain_run/$SuperRunName/VirStrain_summary.txt
	FILE2=$MainF/VirStrain_run/$SuperRunName/GenotypeCalls/VirStrain_summary.txt
	cp $FILE1 $MainF/Results/$SuperRunName/VirStrainSubtypeCalls.txt
	cp $FILE2 $MainF/Results/$SuperRunName/VirStrainGenotypeCalls.txt

fi



# FOR EACH UNIQUE CHRNAME SPLIT & VARIANTCALL AGAIN
if [ $CombineRefs = true ] && [ $VirStrainGenoAndSubTyping = false ]; then
START=1
END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)

for (( linenumber=$START; linenumber<=$END; linenumber++ ))
do

	#linenumber=1
	FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
	FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 
	GenoTypeCallIn=$MainF/GenotypeCalls/$SuperRunName
	GenoTypeCallForFastq=$(< $MainF/GenotypeCalls/$SuperRunName/${FastqInput}.txt)
	BamName=${FastqInput}_${GenoTypeCallForFastq}.sort.bam
	bamtools split -in $ResultsF/$FastqRunInput/$GenoTypeCallForFastq/ResultFiles/$BamName -reference
	#Samler hver splittet fil i en mappe og laver variantcalls

	StartRefs=1
	EndRefs=$(awk 'END{print NR}' $MainF/GenotypeCalls/$SuperRunName/${FastqInput}_SplitTo.txt)
	if [ $EndRefs -gt 1 ]; then 
	for (( linen=$StartRefs; linen<=$EndRefs; linen++ )); do
	#linen=1
	SplitRef=$(awk "NR==$linen" $MainF/GenotypeCalls/$SuperRunName/${FastqInput}_SplitTo.txt)
	mkdir -p $ResultsF/$FastqRunInput/$SplitRef
	SplitBam=$ResultsF/$FastqRunInput/$GenoTypeCallForFastq/ResultFiles/${FastqInput}_${GenoTypeCallForFastq}.sort.REF_${SplitRef}.bam
	mv $SplitBam $ResultsF/$FastqRunInput/$SplitRef/${FastqInput}_${SplitRef}.bam

	#Variant filtrering, indexering og sortering
	VariantCallFromCovGenotypingSplitRefs.sh $FastqRunInput $FastqInput $SuperRunName $MainF $GenoTypeCallIn $SplitRef $BedFileNameX $AmpliconRef 
	done

	fi
	echo fil $FastqInput færdig med split calls... $linenumber af $END fastqfiler

done
fi
#######################################################################




# Fixer navn på vcf filer som har fået fjernet alle filtrerede varianter helt, hvis der ikke har været kombinerede referencer med splittede bamfiler
START=1
END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)
for (( linenumber=$START; linenumber<=$END; linenumber++ ))
do
	FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
	FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 

	FILE1=$MainF/GenotypeCalls/$SuperRunName/${FastqInput}_SplitTo.txt
	FILE2=$MainF/GenotypeCalls/$SuperRunName/${FastqInput}.txt

	# Checker om en fastqfil havde kombinerede referencer eller ej
	if cmp --silent -- "$FILE1" "$FILE2"; then
	StartRefs=1
	EndRefs=$(awk 'END{print NR}' $MainF/GenotypeCalls/$SuperRunName/${FastqInput}_SplitTo.txt)
	for (( linen=$StartRefs; linen<=$EndRefs; linen++ )); do
	#linen=1
	SplitRef=$(awk "NR==$linen" $MainF/GenotypeCalls/$SuperRunName/${FastqInput}_SplitTo.txt)
	# renamer så rscript kan finde vcf fil
	#SplitRef=$(awk "NR==1" $MainF/GenotypeCalls/$SuperRunName/${FastqInput}_SplitTo.txt)
	# Her indsættes hvis der skal bruge dup markerede ".dup."
	cp $ResultsF/$FastqRunInput/${SplitRef}/${SplitRef}.sort.readGroupFix_filtered_FiltEx_headerfix.vcf $ResultsF/$FastqRunInput/${SplitRef}/${FastqInput}_${SplitRef}.sort.readGroupFix_filtered_FiltEx_headerfix.vcf
	done
	fi

done



# Følgende scripts læser hvilke FASTQfiler der skal behandles fra FASTQfiles_[navn].txt og FASTQfiles_[navn]_run.txt filerne

if [ $RunAnnoRSCript = true ] && [ $E4SpliceCalls = false ]; then

	# Dette script tager selv fat i nødvendige Fastfiler fra MultiFQFile
	Rscript $Rscriptfolder/Annotate_vcf_multiple_for_bash_v2FromGenotypeCalls.R $MainF $MainF/Annotation_results $SuperRunName $MultiFQFile

	# Fix For No call script, hvor multiple aminosyrer ændringer vises med ", " og ændrer til ","
	sed -i 's/,\s/,/g' $MainF/Annotation_results/ForNoCallScript_FASTQfiles_${SuperRunName}_Nuc_change_coords.txt

fi


if [ $E4SpliceCalls = true ]; then

	# Dette script tager selv fat i nødvendige Fastfiler fra MultiFQFile
	Rscript $Rscriptfolder/Annotate_vcf_multiple_for_bash_wE4SpliceGeneFix.R $MainF $MainF/Annotation_results $SuperRunName $MultiFQFile

	# Fix For No call script, hvor multiple aminosyrer ændringer vises med ", " og ændrer til ","
	sed -i 's/,\s/,/g' $MainF/Annotation_results/ForNoCallScript_FASTQfiles_${SuperRunName}_Nuc_change_coords.txt

fi



# Dette script skal bruge liste over alle referencer der køres. Fungerer kun hvis alle fastq filer har været alignet til samme referencer

if [ $RunSiteCovScript = true ]; then

	START=1
	END=$(awk 'END{print NR}' $MainF/FASTQfiles_${SuperRunName}.txt)
	for (( linenumber=$START; linenumber<=$END; linenumber++ )); do

	FastqInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}.txt)
	FastqRunInput=$(awk "NR==$linenumber" $MainF/FASTQfiles_${SuperRunName}_runnames.txt) 
	Specific_site_covFromCovGenotype.sh $MainF $FastqRunInput $FastqInput $SuperRunName
	
	done

fi



# Kører R No_calls script 

if [ $RunNoCallsScript = true ]; then

	# Laver 1 fil med alle mulige referencer til No_call_script
	find $RefF/ -maxdepth 1 -name '*.fasta' | sed 's/^.*\(References.*fasta\).*$/\1/' | \
	sed 's/.fasta//g' | sed 's/References\///g' > $RefdF/RefSubtyper_latest.txt


	#if [ -d $ResultsF/$FastqRunInput/$refType ]; then
	Rscript $Rscriptfolder/No_calls_on_vcf.R $MainF $MainF/Annotation_results $SuperRunName $MultiFQFile
	# [SaveDir] [ReferenceName] [SuperRunName] [ListOfFastqFiles]

	# Samler splittede annotationresultat filer
	# Undgår første linje, da den er kolonnenavne
	rm -f $MainF/Annotation_results/AnnotationFrequency_FASTQfiles_${SuperRunName}_AllResults.txt
	cat $MainF/Annotation_results/AnnotationFrequency_FASTQfiles_${SuperRunName}*.txt | awk "NR==1 {print}" > colname_${SuperRunName}.txt
	awk FNR!=1 $MainF/Annotation_results/AnnotationFrequency_FASTQfiles_${SuperRunName}*.txt > anno_${SuperRunName}.txt 
	cat colname_${SuperRunName}.txt anno_${SuperRunName}.txt > $MainF/Annotation_results/AnnotationSummary_${SuperRunName}.txt
	rm $MainF/Annotation_results/AnnotationFrequency_FASTQfiles_${SuperRunName}*.txt
	rm colname_${SuperRunName}.txt anno_${SuperRunName}.txt
	cat $MainF/Annotation_results/FASTQfiles_${SuperRunName}_Nuc_change_coords_*.bed > $MainF/Annotation_results/VariantPositions_${SuperRunName}.bed
	rm $MainF/Annotation_results/FASTQfiles_${SuperRunName}_Nuc_change_coords_*.bed

	# Flytter filer for convenience

	cp $MainF/Annotation_results/AnnotationSummary_${SuperRunName}.txt $MainF/Results/$SuperRunName/AnnotationSummary_${SuperRunName}.txt
	cp $MainF/Annotation_results/AnnotationIndividualFiles_${SuperRunName}.txt $MainF/Results/$SuperRunName/AnnotationIndividualFiles_${SuperRunName}.txt

fi




# Fjerner alle filtrerede fastqfiler der blev genereret, så de ikke bliver filtreret en gang til ved ny kørsel og der opstår dobbeltfiler
rm $MainF/FASTQ/*_filt.fastq;
# done
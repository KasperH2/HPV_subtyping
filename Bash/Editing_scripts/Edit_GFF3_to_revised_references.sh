



#### ÆNDRER GFF3 til Revised filnavn og chrnavn

# Vælg fil
FilePath=/home/pato/Skrivebord/HPV16_projekt/References/GFFfiles/
FileName=K02718.1_revised.gff3
NewFile=$FilePath/HPV16_K02718_1_revised.gff3

# Ændrer navn
mv $FilePath/$FileName $NewFile

# Ændrer chrnavn inden i fil
sed -i 's/K02718.1_revised/HPV16_K02718_1_revised/g' $NewFile # -i ændrer inplace (direkte i filen og outputter ikke en ny fil)




# Ændrer gff3 til "_" i stedet for "."
FilePath=/home/pato/Skrivebord/HPV16_projekt/References/GFFfiles

for f in ${FilePath}/*.gff3; do 
	FileName=${f##*/}
	ChrName=${FileName%.gff3}
	NewChrName=$( sed 's/\./_/g' <<< "$ChrName" ) # <<< is a here-string
	
	# Ændrer chrnavn i fil
	sed -i "s/$ChrName/$NewChrName/g" $f

	# Ændrer navn
	mv $f $FilePath/${NewChrName}.gff3
	# rename -n 's/\./_/g' $f

done




# Fjerne duplicate referencer

FilePath=/home/pato/Skrivebord/HPV16_projekt/References/0Andre/HPV_all_types/MSA

for f in $FilePath/*.mafft; do
	awk '/^>/{f=!d[$1];d[$1]=1}f' $f > ${f}.tmp
	mv ${f}.tmp $f
done
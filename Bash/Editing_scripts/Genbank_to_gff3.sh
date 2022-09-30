


bp_genbank2gff 'in.gb' --viral --stdout > 'out.gff3'
# The script seems to remove the ".1" from "K02718.1" in the gff3 file

# HUSK følgende 3 korrigeringer!
# Lav korrekt navn, eks:
sed 's/K02718/K02718.1/g'

# Fjern .t00:
sed 's/.t00//g'


# Sæt CDS phases til 0 (Tjek om de er 0 i genbank fil)
# Kan evt. gøres ved at bygge videre på følgende script
# grep "CDS" $file | awk "CDS" {print $8} 




#Gammelt

# Fjern "_" fra gennavne for at annotation R script ikke kommer til at separere forkert. Der må gerne være "-"" i gennavne, men ikke i referencenavne

# sed 's/_ALPHA/-ALPHA/g'

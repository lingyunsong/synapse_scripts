#!/usr/bin/perl
#Revised by Lingyun Song on 2014-06-25
use strict;
use File::Basename;

my $filter_file_root = '/nfs/furey_sata2/bowtie_pipeline';
my $generic_apps_dir = "/nfs/furey_sata2/bin/";
my $usage = $0.' <build> <bedfile> '."\nProduces files in the same directory as bedfile\n";
my $build = shift or die $usage;
my $bedfile = shift or die $usage;
my $final_bedfile = $bedfile;

#Filter unwanted chromosomes
print STDERR "Filtering out unwanted chromosomes...\n";
my $no_chrom_bedfile = $bedfile.'.no.unwanted.chromosomes';
open (my $no_chrom_out, '>', $no_chrom_bedfile) or die "Could not open ${no_chrom_bedfile} $!\n";
open (my $bed_in, '<', $bedfile) or die "Could not open ${bedfile} $!\n";
while (my $line = <$bed_in>) {
    next if ($line =~ m/^chrUn/ || $line =~ m/^chr.*random/);
    print $no_chrom_out $line;
}
close $no_chrom_out;
close $bed_in;
`mv ${no_chrom_bedfile} ${bedfile}`;
if ($?) {
    print STDERR "Problem mv ${no_chrom_bedfile} ${bedfile} $!\n";
    exit(1);
}

#Filter alpha satellite
print STDERR "Filtering with blacklist...\n";
my $filter_file = join('/', $filter_file_root, $build, 'Blacklist.2014.bed');

my $cmd;
my @zip_files = ($bedfile); # these will be tar-gzipped into a single archive at the end
my $no_alpha_bed = $bedfile;
$no_alpha_bed =~ s/\.bed/.noAlpha.bed/;

if (-e $filter_file) {
    $cmd = join(' ', 
                '/usr/local/bin/bed_intersect.py',
                '-v',
                $bedfile,
                $filter_file,
                '>',
                $no_alpha_bed
                );

    print STDERR "Running ${cmd}\n";
    if (system($cmd)) {
        print "Problem running bed_intersect.py $!\n";
        exit(1);
    }
    print STDERR "Done\n";
} else {
    print STDERR "Adapter file does not exist for ${build}, skipping alpha satellite filter \n";
    `cp $bedfile $no_alpha_bed`;
    if ($?) {
        print STDERR "Problem copying bedfile to no_alpha_bed $!\n";
        exit(1);
    }
}
push @zip_files, $no_alpha_bed;

my $no_artifacts_bed = $bedfile;
my $filtered_artifacts_bed = join('/', File::Basename::dirname($bedfile), 'filtered_artifacts.bed');

    #Filter PCR artifacts
    print STDERR "Filtering sharp, single-base peaks ...\n";
    $cmd = join(' ',
                $generic_apps_dir."filter_artifacts.pl",
                $no_alpha_bed,
                "-out",
                $filtered_artifacts_bed,
                '>',
                "sequence.final.bed"
                );

    if (system($cmd)) {
        print STDERR "Problem creating sequence.final.bed $!\n";
        exit(1);
    }

print STDERR "Done\n";

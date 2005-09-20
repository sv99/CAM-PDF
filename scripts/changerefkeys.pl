#!/usr/bin/perl -w

use strict;
use CAM::PDF;
use Getopt::Long;
use Pod::Usage;

my %opts = (
            verbose    => 0,
            order      => 0,
            help       => 0,
            version    => 0,
            );

Getopt::Long::Configure("bundling");
GetOptions("v|verbose"  => \$opts{verbose},
           "o|order"    => \$opts{order},
           "h|help"     => \$opts{help},
           "V|version"  => \$opts{version},
           ) or pod2usage(1);
pod2usage(-exitstatus => 0, -verbose => 2) if ($opts{help});
print("CAM::PDF v$CAM::PDF::VERSION\n"),exit(0) if ($opts{version});

if (@ARGV < 3)
{
   pod2usage(1);
}

my $infile = shift;
my @nums = (@ARGV);
my $outfile = "-";
if (@nums % 2 != 0)
{
   $outfile = pop @nums;
}

my $doc = CAM::PDF->new($infile);
die "$CAM::PDF::errstr\n" if (!$doc);

$doc->changeRefKeys(CAM::PDF::Node->new("dictionary", $doc->{trailer}), {@nums}, 1);
$doc->preserveOrder() if ($opts{order});
if (!$doc->canModify())
{
   die "This PDF forbids modification\n";
}
$doc->cleanoutput($outfile);

__END__

=head1 NAME

changerefkeys.pl - Search and replace PDF object numbers in the Trailer

=head1 SYNOPSIS

changerefkeys.pl [options] infile.pdf old-objnum new-objnum
                 [old-objnum new-objnum ...] [outfile.pdf]

 Options:
   -o --order          preserve the internal PDF ordering for output
   -v --verbose        print diagnostic messages
   -h --help           verbose help message
   -V --version        print CAM::PDF version

=head1 DESCRIPTION

Changes a PDF to alter the object numbers in the PDF Trailer.  The
resulting edited PDF is output to a specified file or STDOUT.

This is a very low-level utility, and is not likely useful for general
users.

=head1 SEE ALSO

CAM::PDF

=head1 AUTHOR

Clotho Advanced Media Inc., I<cpan@clotho.com>
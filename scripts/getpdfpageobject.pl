#!/usr/bin/perl -w

use strict;
use CAM::PDF;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;

my %opts = (
            decode     => 0,
            content    => 0,
            verbose    => 0,
            help       => 0,
            version    => 0,
            );

Getopt::Long::Configure("bundling");
GetOptions("d|decode"   => \$opts{decode},
           "c|content"  => \$opts{content},
           "v|verbose"  => \$opts{verbose},
           "h|help"     => \$opts{help},
           "V|version"  => \$opts{version},
           ) or pod2usage(1);
pod2usage(-exitstatus => 0, -verbose => 2) if ($opts{help});
print("CAM::PDF v$CAM::PDF::VERSION\n"),exit(0) if ($opts{version});

if (@ARGV < 2)
{
   pod2usage(1);
}

my $file = shift;
my $pagenum = shift;

if ($pagenum !~ /^\d+$/ || $pagenum < 1)
{
   die "The page number must be an integer greater than 0\n";
}

my $doc = CAM::PDF->new($file);
die "$CAM::PDF::errstr\n" if (!$doc);

my $page = $doc->getPage($pagenum);

if ($opts{content})
{
   if (!exists $page->{Contents})
   {
      die "No page content found\n";
   }
   $page = $doc->getValue($page->{Contents});
}

$doc->decodeAll(CAM::PDF::Node->new("dictionary",$page)) if ($opts{decode});

if ($opts{verbose})
{
   print Data::Dumper->Dump([$page], ["page"]);
}


__END__

=head1 NAME

getpdfpageobject.pl - Print the PDF page metadata

=head1 SYNOPSIS

getpdfpageobject.pl [options] infile.pdf pagenum

 Options:
   -d --decode         uncompress any elements
   -c --content        show the page Contents field only
   -v --verbose        print diagnostic messages
   -h --help           verbose help message
   -V --version        print CAM::PDF version

=head1 DESCRIPTION

Retrieves the page metadata from the PDF.  If --verbose is specified,
the memory representation is dumped to STDOUT.  Otherwise, the program
silently returns success or emits a failure message to STDERR.

=head1 SEE ALSO

CAM::PDF

getpdfpage.pl

setpdfpage.pl

=head1 AUTHOR

Clotho Advanced Media Inc., I<cpan@clotho.com>
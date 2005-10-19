#!/usr/bin/perl -w

use warnings;
use strict;
use CAM::PDF;
use Getopt::Long;
use Pod::Usage;
use English qw(-no_match_vars);

my %opts = (
            density    => undef,
            xdensity    => undef,
            ydensity    => undef,
            check      => 0,
            renderer   => 'CAM::PDF::Renderer::Dump',
            verbose    => 0,
            help       => 0,
            version    => 0,
            );

Getopt::Long::Configure('bundling');
GetOptions('r|renderer=s' => \$opts{renderer},
           'd|density=f'  => \$opts{density},
           'x|xdensity=f' => \$opts{xdensity},
           'y|ydensity=f' => \$opts{ydensity},
           'c|check'      => \$opts{check},
           'v|verbose'    => \$opts{verbose},
           'h|help'       => \$opts{help},
           'V|version'    => \$opts{version},
           ) or pod2usage(1);
if ($opts{help})
{
   pod2usage(-exitstatus => 0, -verbose => 2);
}
if ($opts{version})
{
   print "CAM::PDF v$CAM::PDF::VERSION\n";
   exit 0;
}

if (defined $opts{density})
{
   $opts{xdensity} = $opts{ydensity} = $opts{density};
}
if (defined $opts{xdensity} || defined $opts{ydensity})
{
   eval "require $opts{renderer}";  ## no critic for string eval
   if ($EVAL_ERROR)
   {
      die $EVAL_ERROR;
   }
   if (defined $opts{xdensity})
   {
      no strict 'refs';
      my $varname = $opts{renderer}.'::xdensity';
      $$varname = $opts{xdensity};
   }
   if (defined $opts{ydensity})
   {
      no strict 'refs';
      my $varname = $opts{renderer}.'::ydensity';
      $$varname = $opts{ydensity};
   }
}

if (@ARGV < 1)
{
   pod2usage(1);
}

my $file = shift;
my $pagelist = shift;

my $doc = CAM::PDF->new($file) || die "$CAM::PDF::errstr\n";

foreach my $p ($doc->rangeToArray(1, $doc->numPages(), $pagelist))
{
   my $tree = $doc->getPageContentTree($p, $opts{verbose});
   if ($opts{check})
   {
      print "Checking page $p\n";
      if (!$tree->validate())
      {
         print "  Failed\n";
      }
   }
   $tree->render($opts{renderer});
}


__END__

=head1 NAME

renderpdf.pl - Applies a renderer to one or more PDF pages

=head1 SYNOPSIS

renderpdf.pl [options] infile.pdf [<pagenums>]

 Options:
   -r --renderer=class uses this renderer class (default: CAM::PDF::Renderer::Dump)
   -c --check          validates the page before rendering it
   -d --density=float  sets the X and Y density for the renderer
   -x --xdensity=float sets the X density for the renderer
   -y --ydensity=float sets the Y density for the renderer
   -v --verbose        print diagnostic messages
   -h --help           verbose help message
   -V --version        print CAM::PDF version

 <pagenums> is a comma-separated list of page numbers.
      Ranges like '2-6' allowed in the list
      Example: 4-6,2,12,8-9

=head1 DESCRIPTION

Loads and runs the chosen renderer on the specified pages of the PDF.
If no pages are specified, all are processed.

The density flags are used for graphical renderers (namely
CAM::PDF::Renderer::Text and the like).

=head1 SEE ALSO

CAM::PDF

getpdftext.pl

=head1 AUTHOR

Clotho Advanced Media Inc., I<cpan@clotho.com>

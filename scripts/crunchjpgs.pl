#!/usr/bin/perl -w

use warnings;
use strict;
use CAM::PDF;
use Getopt::Long;
use Pod::Usage;

my %opts = (
            # Hardcoded:
            template   => 'crunchjpg_tmpl.pdf',

            # User settable values:
            justjpgs   => 0,
            quality    => 50,
            scale      => undef,
            scalemin   => 0,
            skip       => {},
            only       => {},
            Verbose    => 0,
            verbose    => 0,
            order      => 0,
            help       => 0,
            version    => 0, 

            # Temporary values:
            onlyval    => [],
            skipval    => [],
            qualityval => undef,
            scaleminval=> undef,
            scaleval   => undef,
            scales     => {1 => undef, 2 => '50%', 4 => '25%', 8 => '12.5%'},
           );

Getopt::Long::Configure('bundling');
GetOptions('S|skip=s'     => \@{$opts{skipval}},
           'O|only=s'     => \@{$opts{onlyval}},
           'q|quality=i'  => \$opts{qualityval},
           's|scale=i'    => \$opts{scaleval},
           'm|scalemin=i' => \$opts{scaleminval},
           'j|justjpgs'   => \$opts{justjpgs},
           'veryverbose'  => \$opts{Verbose},
           'v|verbose'    => \$opts{verbose},
           'o|order'      => \$opts{order},
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

## Fix up and validate special options:

if ($opts{Verbose})
{
   $opts{verbose} = 1;
}
if (defined $opts{scaleval})
{
   if (exists $opts{scales}->{$opts{scaleval}})
   {
      $opts{scale} = $opts{scales}->{$opts{scaleval}};
   }
   else
   {
      die "Invalid value for --scale switch\n";
   }
}
if (defined $opts{scaleminval})
{
   if ($opts{scaleminval} =~ /^\d+$/ && $opts{scaleminval} > 0)
   {
      $opts{scalemin} = $opts{scaleminval};
   }
   else
   {
      die "Invalid value for --scalemin switch\n";
   }
}
if (defined $opts{qualityval})
{
   if ($opts{qualityval} =~ /^\d+$/ && $opts{qualityval} >= 1 && $opts{qualityval} <= 100)
   {
      $opts{quality} = $opts{qualityval};
   }
   else
   {
      die "The JPEG --quality setting must be between 1 and 100\n";
   }
}
foreach my $flag (qw( skip only ))
{
   foreach my $val (@{$opts{$flag.'val'}})
   {
      foreach my $key (split /\D+/, $val)
      {
         $opts{$flag}->{$key} = 1;
      }
   }
}
if (!-f $opts{template})
{
   die "Cannot find the template pdf called $opts{template}\n";
}

# Start work:

if (@ARGV < 1)
{
   pod2usage(1);
}

my $infile = shift;
my $outfile = shift || q{-};

my $doc = CAM::PDF->new($infile) || die "$CAM::PDF::errstr\n";

if (!$doc->canModify())
{
   die "This PDF forbids modification\n";
}

my $pages = $doc->numPages();
my $nimages = 0;
my $rimages = 0;

my %doneobjs = ();

my $oldcontentsize = $doc->{contentlength};
my $oldtotsize = 0;
my $newtotsize = 0;

for my $p (1..$pages)
{
   my $c = $doc->getPageContent($p);
   my @parts = split /(\/[\w]+\s*Do)\b/s, $c;
   foreach my $part (@parts)
   {
      if ($part =~ /^(\/[\w]+)\s*Do$/s)
      {
         my $ref = $1;
         my $xobj = $doc->dereference($ref, $p);
         my $objnum = $xobj->{objnum};
         my $im = $doc->getValue($xobj);
         my $l = $im->{Length} || $im->{L} || 0;
         if ($l)
         {
            $l = $doc->getValue($l);
         }
         my $w = $im->{Width} || $im->{W} || 0;
         if ($w)
         {
            $w = $doc->getValue($w);
         }
         my $h = $im->{Height} || $im->{H} || 0;
         if ($h)
         {
            $h = $doc->getValue($h);
         }

         next if (exists $doneobjs{$objnum});

         $nimages++;
         _inform("Image $nimages page $p, $ref = object $objnum, (w,h)=($w,$h), length $l", $opts{verbose});

         if (exists $opts{skip}->{$objnum} ||
             (0 < scalar keys %{$opts{only}} && !exists $opts{only}->{$objnum}))
         {
            _inform("Skipping object $objnum", $opts{verbose});
            next;
         }

         my $isjpg = 0;
         if ($im->{Filter})
         {
            my $f = $im->{Filter};
            if ($f->{type} eq 'array')
            {
               foreach my $e (@{$f->{value}})
               {
                  my $name = $doc->getValue($e);
                  if (ref $name)
                  {
                     $name = $name->{value};
                  }
                  #warn "Checking $name\n";
                  if ($name eq 'DCTDecode')
                  {
                     $isjpg = 1;
                     last;
                  }
               }
            }
            else
            {
               my $name = $doc->getValue($f);
               if (ref $name)
               {
                  $name = $name->{value};
               }
               #warn "Checking $name\n";
               if ($name eq 'DCTDecode')
               {
                  $isjpg = 1;
               }
            }
         }

         if ((!$isjpg) && $opts{justjpgs})
         {
            _inform('Not a jpeg', $opts{verbose});
         }
         else
         {
            my $oldsize = $doc->getValue($im->{Length});
            if (!$oldsize)
            {
               die "PDF error: Failed to get size of image\n";
            }
            $oldtotsize += $oldsize;

            my $tmpl = CAM::PDF->new($opts{template}) || die "$CAM::PDF::errstr\n";
            
            # Get a handle on the needed data bits from the template
            my $media_array = $tmpl->getValue($tmpl->getPage(1)->{MediaBox});
            my $rawpage = $tmpl->getPageContent(1);
            
            $media_array->[2]->{value} = $w;
            $media_array->[3]->{value} = $h;
            my $page = $rawpage;
            $page =~ s/xxx/$w/ig;
            $page =~ s/yyy/$h/ig;
            $tmpl->setPageContent(1, $page);
            $tmpl->replaceObject(9, $doc, $objnum, 1);

            my $ofile = "/tmp/crunchjpg.$$";
            $tmpl->cleanoutput($ofile);

            my $cmd = ('convert ' . 
                       ($opts{scale} && $w > $opts{scalemin} && $h > $opts{scalemin} ?
                        "-scale '$opts{scale}' " : q{}) . 
                       "-quality $opts{quality} " .
                       '-density 72x72 ' .
                       "-page ${w}x$h " .
                       "pdf:$ofile jpg:- | " .
                       'convert jpg:- pdf:- |');

            _inform($cmd, $opts{Verbose});

            open my $pipe, $cmd
                or die "Failed to convert object $objnum to a jpg and back\n";
            my $content = join q{}, <$pipe>;
            close $pipe 
                or die "Failed to convert object $objnum to a jpg and back\n";

            my $jpg = CAM::PDF->new($content) || die "$CAM::PDF::errstr\n";

            $doc->replaceObject($objnum, $jpg, 9, 1);

            my $newim = $doc->getObjValue($objnum);
            my $newsize = $doc->getValue($newim->{Length});
            $newtotsize += $newsize;

            my $percent = sprintf '%.1f', 100 * ($oldsize - $newsize) / $oldsize;
            _inform("compressed $oldsize -> $newsize ($percent%)", $opts{verbose});

            $doneobjs{$objnum} = 1;
            $rimages++;
         }
      }
   }
}

_inform("Crunched $rimages of $nimages images", $opts{verbose});
$doc->cleanoutput($outfile);

my $newcontentsize = $doc->{contentlength};

if ($opts{verbose})
{
   my $contentpercent = sprintf '%.1f', $oldcontentsize ? 100 * ($oldcontentsize - $newcontentsize) / $oldcontentsize : 0;
   my $totpercent = sprintf '%.1f', $oldtotsize ? 100 * ($oldtotsize - $newtotsize) / $oldtotsize : 0;
   _inform('Compression summary:', 1);
   _inform("  Document: $oldcontentsize -> $newcontentsize ($contentpercent%)", 1);
   _inform("  Images: $oldtotsize -> $newtotsize ($totpercent%)", 1);
}


sub _inform
{
   my $str     = shift;
   my $verbose = shift;

   if ($verbose)
   {
      print STDERR $str, "\n";
   }
}

__END__

=head1 NAME

crunchjpgs.pl - Compress all JPG images in a PDF

=head1 SYNOPSIS

crunchjpgs.pl [options] infile.pdf [outfile.pdf]

 Options:
   -j --justjpgs       make script skip non-JPGs
   -q --quality        select JPG output quality (default 50)
   -s --scale=num      select a rescaling factor for the JPGs (default 100%)
   -m --scalemin=size  don't scale JPGs smaller than this pixel size (width or height)
   -O --only=imnum     only change the specified images (can be used mutliple times)
   -S --skip=imnum     don't change the specified images (can be used mutliple times)
   -o --order          preserve the internal PDF ordering for output
      --veryverbose    increases the verbosity
   -v --verbose        print diagnostic messages
   -h --help           verbose help message
   -V --version        print CAM::PDF version

The available values for --scale are:

    1  100%
    2   50%
    4   25%
    8   12.5%

C<imnum> is a comma-separated list of integers indicating the images
in order that they appear in the PDF.  Use listimages.pl to retrieve
the image numbers.

=head1 DESCRIPTION

Requires the ImageMagick C<convert> program to be available

Tweak all of the JPG images embedded in a PDF to reduce their size.
This reduction can come from increasing the compression and/or
rescaling the whole image.  Various options give you full control over
which images are altered.

=head1 SEE ALSO

CAM::PDF

listimages.pl

extractallimages.pl

extractjpgs.pl

uninlinepdfimages.pl

=head1 AUTHOR

Clotho Advanced Media Inc., I<cpan@clotho.com>

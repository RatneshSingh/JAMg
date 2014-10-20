#!/usr/local/bin/perl 
##---------------------------------------------------------------------------##
##  File:
##      @(#) MultAln.pm
##  Authors:
##      Robert M. Hubley   rhubley@systemsbiology.org
##      Arian Smit         asmit@systemsbiology.org
##      Arnie Kas	   akas@u.washington.edu
##  Description:
##      Module for handling multiply aligned sequences to a
##      reference sequence.
##
#******************************************************************************
#* Copyright (C) Institute for Systems Biology 2004 Developed by
#* Robert Hubley, Arian Smit and Arnie Kas.
#*
#* This work is licensed under the Open Source License v2.1.  To view a copy
#* of this license, visit http://www.opensource.org/licenses/osl-2.1.php or
#* see the license.txt file contained in this distribution.
#*
###############################################################################
#  ChangeLog:
#
#    $Log: MultAln.pm,v $
#    Revision 1.40  2014/05/23 17:21:51  rhubley
#    Cleanup before a distribution
#
#
###############################################################################
##   A MultAln object has the following structure:
##
##
## OLD:
## bless( {
##           'alignCol' => [
##                       {
##                         'end' => '20333',
##                         'start' => 0,
##                         'seqStart' => '13',
##                         'seq' => 'AAG-TGT-----G-----G-',
##			   'name' => 'Charlie1#DNA/MER1_type',
##			   'gcBackground' => '',
##			   'div' => '',
##			   'transI' => '',
##			   'transV' => '',
##			   'srcDiv' => ''
##			 },
##                       {
##                         'end' => '2030',
##                         'start' => '100',
##                         'seqStart' => '203893',
##                         'seq' => 'AAG-TGT-----G-----G-',
##			   'name' => 'seq-1',
##			   'gcBackground' => '37',
##			   'div' => '20',
##			   'transI' => '2',
##			   'transV' => '4',
##			   'srcDiv' => '22.1'
##			 },
##			 {...}
##		       ]
##         }
##       );
##
## NEW:
## bless( {
##           'alignCol' => [
##                        {
##                         'end' => '20333',
##                         'start' => 0,
##                         'seqStart' => '13',
##                         'lfSeq' => '',
##                         'rfSeq' => '',
##                         'seq' => 'AAG-TGT-----G-----G-',
##			   'name' => 'Charlie1#DNA/MER1_type',
##			   'gcBackground' => '',
##			   'div' => '',
##                         'kdiv' => '',
##			   'transI' => '',
##			   'transV' => '',
##			   'srcDiv' => ''
##			 },
##           'consensus' => '',
##           'lowQualityBlocks => [ [ start, end ], [..] ]
##         });
##
##
#******************************************************************************

=head1 NAME

MultAln.pm - Module to hold multiple alignments to a reference sequence.

=head1 SYNOPSIS

use MultAln;

Usage:

   my $mAlign = MultAln->new();

  or

   my $mAlign = MultAln->new( 
                        searchCollection => $mySearchResultCollection,
                        searchCollectionReference => MultAln::Query,
                        referenceSequence => "ACCAAA...AAAA",
                       [ flankingSequenceDatabase => $seqDBRef, ]
                       [ maxFlankingSequenceLen => -1, ]
                            );

=head1 DESCRIPTION

A class to hold alignments to a reference sequence. This object
can be built from a SearchResultCollection.pm object.  The default
behaviour is to use the Query sequence as the reference sequence
however this may be changed using the "searchCollectionReference" 
parameter.

Each sequence ( including the reference ) may also store it's flanking
sequence.  If a seqDB is provided as a parameter the flanking sequence
will be looked up in the database and included in the object  up to 
50 bp ( deafult ) on each side of the multiple alignment sequence.  
It is possible to set and/or override the max flanking sequence length
by setting the maxFlankingSequenceLen parameter.  NOTE: A value of -1 is
interpreted as "no limit" -- be careful as this may exhaust memory if your
database is large.


seq(0) is the reference sequence
seq(1..N) are the instance sequence(s)

=head1 SEE ALSO

=over 4

RepeatModeler, SearchResultCollection, SequenceSimilarityMatrix

=back

=head1 COPYRIGHT

Copyright 2004 Institute for Systems Biology

=head1 AUTHOR

Robert Hubley <rhubley@systemsbiology.org>
Arian Smit <asmit@systemsbiology.org>
Arnie Kas <akas@u.washington.edu>

=head1 ATTRIBUTES

=cut

#
# Module Dependence
#
package MultAln;
use strict;
use Data::Dumper;
use SequenceSimilarityMatrix;
use Carp;

# RepeatModeler Libraries
use RepModelConfig;
use lib $RepModelConfig::REPEATMASKER_DIR;
use SearchResultCollection;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use constant Query             => 1;
use constant Subject           => 2;
use constant MaxFlankingSeqLen => 50;

require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw();

@EXPORT_OK = qw();

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

my $CLASS   = "MultAln";
my $VERSION = 2.0;
my $DEBUG   = 0;
##---------------------------------------------------------------------##
## Constructor
##---------------------------------------------------------------------##
sub new
{
  my $class          = shift;
  my %nameValuePairs = @_;

  # Create ourself as a hash
  my $this = {};

  # Bless this hash in the name of the father, the son...
  bless $this, $class;

  if ( defined $nameValuePairs{'searchCollection'} )
  {
    $this->_alignFromSearchResultCollection( %nameValuePairs );
  }

  return $this;
}

##---------------------------------------------------------------------##
## Get and Set Methods
##---------------------------------------------------------------------##

##---------------------------------------------------------------------##

=head2 get_set_LeftFlankingSequence()

  Use: my $value    = getLeftFlankingSequence( $seqNum );

  Use: my $oldValue = setLeftFlankingSequence( $seqNum, $value );

  Get/Set the LeftFlankingSequence attribute of a particular 
  alignment entry.

=cut

##---------------------------------------------------------------------##
sub getLeftFlankingSequence
{
  my $this   = shift;
  my $seqNum = shift;

  return $this->{'alignCol'}->[ $seqNum ]->{'lfSeq'};
}

sub setLeftFlankingSequence
{
  my $this   = shift;
  my $seqNum = shift;
  my $value  = shift;

  my $oldValue = $this->{'alignCol'}->[ $seqNum ]->{'lfSeq'};
  $this->{'alignCol'}->[ $seqNum ]->{'lfSeq'} = $value;

  return $oldValue;
}

##---------------------------------------------------------------------##

=head2 get_set_RightFlankingSequence()

  Use: my $value    = getRightFlankingSequence( $seqNum );

  Use: my $oldValue = setRightFlankingSequence( $seqNum, $value );

  Get/Set the RightFlankingSequence attribute of a particular
  alignment entry.

=cut

##---------------------------------------------------------------------##
sub getRightFlankingSequence
{
  my $this   = shift;
  my $seqNum = shift;

  return $this->{'alignCol'}->[ $seqNum ]->{'rfSeq'};
}

sub setRightFlankingSequence
{
  my $this   = shift;
  my $seqNum = shift;
  my $value  = shift;

  my $oldValue = $this->{'alignCol'}->[ $seqNum ]->{'rfSeq'};
  $this->{'alignCol'}->[ $seqNum ]->{'rfSeq'} = $value;

  return $oldValue;
}

##---------------------------------------------------------------------##

=head2 AlignedOrientation()

  Use: my $value    = getAlignedOrientation( $seqNum );

  Use: my $oldValue = setAlignedOrientation( $seqNum, "+" or "-" );

  Get/Set the orientation attribute of a particular 
  alignment entry.  The valid settings are "+" for forward strand
  and "-" for reverse strand.

=cut

##---------------------------------------------------------------------##
sub getAlignedOrientation
{
  my $this   = shift;
  my $seqNum = shift;

  return $this->{'alignCol'}->[ $seqNum ]->{'orient'};
}

sub setAlignedOrientation
{
  my $this   = shift;
  my $seqNum = shift;
  my $value  = shift;

  croak $CLASS
      . "::setAlignedOrientation( $seqNum, $value ): "
      . "Incorrect orientation value.  Should be \"+\" or \"-\"!\n"
      if ( $value ne "+" && $value ne "-" );

  my $oldValue = $this->{'alignCol'}->[ $seqNum ]->{'orient'};
  $this->{'alignCol'}->[ $seqNum ]->{'orient'} = $value;

  return $oldValue;
}

##---------------------------------------------------------------------##

=head2 getGappedReferenceLength()

  Use: my $value = getGappedReferenceLength();

  Get the length of the reference sequence including gap characters.
  NOTE: This is a replacement for the old "OBJ::length()" method.

=cut

##---------------------------------------------------------------------##
sub getGappedReferenceLength
{
  my $this = shift;

  if ( !defined $this->{'length'} )
  {
    $this->{'length'} = length( $this->getReferenceSeq() );
  }
  return $this->{'length'};
}

##---------------------------------------------------------------------##

=head2 AlignedSeq()

  Use: my $value    = getAlignedSeq( $seqNum );

  Use: my $oldValue = setAlignedSeq( $seqNum, $value );

  Get/Set an aligned sequence.  The sequences are indexed from
  0 - ( $obj->getNumAlignedSeqs() - 1 ). 

  NOTE: This is a replacement for the old "OBJ::seq()" method
  accept that it doesn't include the reference sequence in 
  with the aligned sequences.

=cut

##---------------------------------------------------------------------##
sub getAlignedSeq
{
  my $this   = shift();
  my $seqNum = shift();

  croak $CLASS. "::getAlignedSeq( $this, $seqNum ): Index out of bounds!\n"
      if ( $seqNum < 0 || $seqNum > ( $#{ $this->{'alignCol'} } - 1 ) );

  return ( $this->{'alignCol'}[ $seqNum + 1 ]{'seq'} );
}

sub setAlignedSeq
{
  my $this   = shift();
  my $seqNum = shift();
  my $value  = shift();

  croak $CLASS
      . "::setAlignedSeq( $this, $seqNum, $value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ $seqNum + 1 ]{'seq'};
  $this->{'alignCol'}[ $seqNum + 1 ]{'seq'} = $value;

  return $oldValue;
}

##---------------------------------------------------------------------##

=head2 ReferenceSeq()

  Use: my $value    = getReferenceSeq( );

  Use: my $oldValue = setReferenceSeq( $value );

  Get/Set the reference sequence.  

  NOTE: This is a replacement for the old "OBJ::seq()" method
  accept that it doesn't include access to the aligned sequences.

=cut

##---------------------------------------------------------------------##
sub getReferenceSeq
{
  my $this = shift();

  return ( $this->{'alignCol'}[ 0 ]{'seq'} );
}

sub setReferenceSeq
{
  my $this  = shift();
  my $value = shift();

  croak $CLASS
      . "::setReferenceSeq( $this,$value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ 0 ]{'seq'};
  $this->{'alignCol'}[ 0 ]{'seq'} = $value;

  return $oldValue;
}

##
## Deprecated!
##
sub seq
{
  my $object = shift;
  my $i      = shift;
  @_
      ? $object->{'alignCol'}[ $i ]{seq} = shift
      : $object->{'alignCol'}[ $i ]{seq};
}

##---------------------------------------------------------------------##

=head2 AlignedStart()

  Use: my $value    = $obj->getAlignedStart( $seqNum );

  Use: my $oldValue = $obj->setAlignedStart( $seqNum, $value );

  Get/Set the relative position ( to the reference ) of an aligned sequence.  
  The sequences are indexed from 0 - ( $obj->getNumAlignedSeqs() - 1 ) and
  positions go from 0 to $obj->getReferenceLength().

  NOTE: This is a replacement for the old "OBJ::start()" method
  except that it doesn't include the reference sequence in 
  with the aligned sequences.

=cut

##---------------------------------------------------------------------##
sub getAlignedStart
{
  my $this   = shift();
  my $seqNum = shift();

  croak $CLASS. "::getAlignedStart( $this, $seqNum ): Index out of bounds!\n"
      if ( $seqNum < 0 || $seqNum > ( $#{ $this->{'alignCol'} } - 1 ) );

  return ( $this->{'alignCol'}[ $seqNum + 1 ]{'start'} );
}

sub setAlignedStart
{
  my $this   = shift();
  my $seqNum = shift();
  my $value  = shift();

  croak $CLASS
      . "::setAlignedStart( $this, $seqNum, $value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ $seqNum + 1 ]{'start'};
  $this->{'alignCol'}[ $seqNum + 1 ]{'start'} = $value;

  return $oldValue;
}

##---------------------------------------------------------------------##

=head2 AlignedEnd()

  Use: my $value    = getAlignedEnd( $seqNum );

  Use: my $oldValue = setAlignedEnd( $seqNum, $value );

  Get/Set the relative end position ( to the reference ) of an 
  aligned sequence.  The sequences are indexed from 
  0 - ( $obj->getNumAlignedSeqs() - 1 ) and
  positions go from 0 to $obj->getReferenceLength().

  NOTE: This is a replacement for the old "OBJ::end()" method
  except that it doesn't include the reference sequence in 
  with the aligned sequences.

=cut

##---------------------------------------------------------------------##
sub getAlignedEnd
{
  my $this   = shift();
  my $seqNum = shift();

  croak $CLASS. "::getAlignedEnd( $this, $seqNum ): Index out of bounds!\n"
      if ( $seqNum < 0 || $seqNum > ( $#{ $this->{'alignCol'} } - 1 ) );

  return ( $this->{'alignCol'}[ $seqNum + 1 ]{'end'} );
}

sub setAlignedEnd
{
  my $this   = shift();
  my $seqNum = shift();
  my $value  = shift();

  croak $CLASS
      . "::setAlignedEnd( $this, $seqNum, $value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ $seqNum + 1 ]{'end'};
  $this->{'alignCol'}[ $seqNum + 1 ]{'end'} = $value;

  return $oldValue;
}

##---------------------------------------------------------------------##

=head2 AlignedSeqStart()

  Use: my $value    = getAlignedSeqStart( $seqNum );

  Use: my $oldValue = setAlignedSeqStart( $seqNum, $value );

  Get/Set the absolute position ( from the actual input alignments ) of 
  an aligned sequence.  The sequences are indexed from 
  0 - ( $obj->getNumAlignedSeqs() - 1 ) and positions come from
  the searchResultCollection and are numbered from 1 to 
  the length of the original aligned sequence.

  NOTE: This is a replacement for the old "OBJ::seqStart()" method
  accept that it doesn't include the reference sequence in 
  with the aligned sequences.

=cut

##---------------------------------------------------------------------##
sub getAlignedSeqStart
{
  my $this   = shift();
  my $seqNum = shift();

  croak $CLASS. "::getAlignedSeqStart( $this, $seqNum ): Index out of bounds!\n"
      if ( $seqNum < 0 || $seqNum > ( $#{ $this->{'alignCol'} } - 1 ) );

  return ( $this->{'alignCol'}[ $seqNum + 1 ]{'seqStart'} );
}

sub setAlignedSeqStart
{
  my $this   = shift();
  my $seqNum = shift();
  my $value  = shift();

  croak $CLASS
      . "::setAlignedSeqStart( $this, $seqNum, $value ): Missing "
      . "value parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ $seqNum + 1 ]{'seqStart'};
  $this->{'alignCol'}[ $seqNum + 1 ]{'seqStart'} = $value;

  return $oldValue;
}

##---------------------------------------------------------------------##

=head2 ReferenceSeqStart()

  Use: my $value    = getReferenceSeqStart( $seqNum );

  Use: my $oldValue = setReferenceSeqStart( $value );

  Get/Set the absolute position ( from the actual input alignments ) of 
  the reference sequence.  The positions come from
  the searchResultCollection and are numbered from 1 to 
  the length of the original aligned sequence.

  NOTE: This is a replacement for the old "OBJ::seqStart()" method
  accept that it doesn't include the aligned sequences.

=cut

##---------------------------------------------------------------------##
sub getReferenceSeqStart
{
  my $this = shift();

  return ( $this->{'alignCol'}[ 0 ]{'seqStart'} );
}

sub setReferenceSeqStart
{
  my $this  = shift();
  my $value = shift();

  croak $CLASS
      . "::setReferenceSeqStart( $this, $value ): Missing "
      . "value parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ 0 ]{'seqStart'};
  $this->{'alignCol'}[ 0 ]{'seqStart'} = $value;

  return $oldValue;
}

##---------------------------------------------------------------------##

=head2 ReferenceName()

  Use: my $value    = getReferenceName( );

  Use: my $oldValue = setReferenceName( $value );

  Get/Set the name of the reference sequence.  

  NOTE: This is a replacement for the old "OBJ::name()" method
  accept that it doesn't include access to the aligned sequences.

=cut

##---------------------------------------------------------------------##
sub getReferenceName
{
  my $this = shift();

  return ( $this->{'alignCol'}[ 0 ]{'name'} );
}

sub setReferenceName
{
  my $this  = shift();
  my $value = shift();

  croak $CLASS
      . "::setReferenceName( $this,$value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ 0 ]{'name'};
  $this->{'alignCol'}[ 0 ]{'name'} = $value;

  return $oldValue;
}

##---------------------------------------------------------------------##

=head2 AlignedName()

  Use: my $value    = getAlignedName( $seqNum );

  Use: my $oldValue = setAlignedName( $value );

  Get/Set the name of an aligned sequence. The sequences are indexed from
  0 - ( $obj->getNumAlignedSeqs() - 1 ).

  NOTE: This is a replacement for the old "OBJ::name()" method
  accept that it doesn't include access to the reference sequence.

=cut

##---------------------------------------------------------------------##
sub getAlignedName
{
  my $this   = shift();
  my $seqNum = shift();

  croak $CLASS. "::getAlignedName( $this, $seqNum ): Index out of bounds!\n"
      if ( $seqNum < 0 || $seqNum > ( $#{ $this->{'alignCol'} } - 1 ) );

  return ( $this->{'alignCol'}[ $seqNum + 1 ]{'name'} );
}

sub setAlignedName
{
  my $this   = shift();
  my $seqNum = shift();
  my $value  = shift();

  croak $CLASS
      . "::setAlignedName( $this, $seqNum, $value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ $seqNum + 1 ]{'name'};
  $this->{'alignCol'}[ $seqNum + 1 ]{'name'} = $value;

  return $oldValue;
}

##---------------------------------------------------------------------##

=head2 AlignedDiv()

  Use: my $value    = getAlignedDiv( $seqNum );

  Use: my $oldValue = setAlignedDiv( $value );

  Get/Set the name of an aligned sequence. The sequences are indexed from
  0 - ( $obj->getNumAlignedSeqs() - 1 ).

  NOTE: This is a replacement for the old "OBJ::div()" method
  accept that it doesn't include access to the reference sequence.

=cut

##---------------------------------------------------------------------##
sub setAlignedDiv
{
  my $this   = shift();
  my $seqNum = shift();
  my $value  = shift();

  croak $CLASS
      . "::setAlignedDiv( $this, $seqNum, $value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ $seqNum + 1 ]{'div'};
  $this->{'alignCol'}[ $seqNum + 1 ]{'div'} = $value;

  return $oldValue;
}

sub getAlignedDiv
{
  my $this   = shift;
  my $seqNum = shift;

  croak $CLASS. "::getAlignedDiv( $this, $seqNum ): Index out of bounds!\n"
      if ( $seqNum < 0 || $seqNum > ( $#{ $this->{'alignCol'} } - 1 ) );

  return ( $this->{'alignCol'}[ $seqNum + 1 ]{'div'} );
}

##---------------------------------------------------------------------##

=head2 AlignedGCBackground()

  Use: my $value    = getAlignedGCBackground( $seqNum );

  Use: my $oldValue = setAlignedGCBackground( $seqNum, $value );

  Get/Set the gcBackground of an aligned sequence. The sequences are indexed from
  0 - ( $obj->getNumAlignedSeqs() - 1 ).

  NOTE: This is a replacement for the old "OBJ::gcBackground()" method
  accept that it doesn't include access to the reference sequence.

=cut

##---------------------------------------------------------------------##
sub setAlignedGCBackground
{
  my $this   = shift();
  my $seqNum = shift();
  my $value  = shift();

  croak $CLASS
      . "::setAlignedGCBackground( $this, $seqNum, $value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ $seqNum + 1 ]{'gcBackground'};
  $this->{'alignCol'}[ $seqNum + 1 ]{'gcBackground'} = $value;

  return $oldValue;
}

sub getAlignedGCBackground
{
  my $this   = shift;
  my $seqNum = shift;

  croak $CLASS
      . "::getAlignedGCBackground( $this, $seqNum ): Index out of bounds!\n"
      if ( $seqNum < 0 || $seqNum > ( $#{ $this->{'alignCol'} } - 1 ) );

  return ( $this->{'alignCol'}[ $seqNum + 1 ]{'gcBackground'} );
}

##---------------------------------------------------------------------##

=head2 AlignedTransI()

  Use: my $value    = getAlignedTransI( $seqNum );

  Use: my $oldValue = setAlignedTransI( $seqNum, $value );

  Get/Set the transI of an aligned sequence. The sequences are indexed from
  0 - ( $obj->getNumAlignedSeqs() - 1 ).

  NOTE: This is a replacement for the old "OBJ::transI()" method
  accept that it doesn't include access to the reference sequence.

=cut

##---------------------------------------------------------------------##
sub setAlignedTransI
{
  my $this   = shift();
  my $seqNum = shift();
  my $value  = shift();

  croak $CLASS
      . "::setAlignedTransI( $this, $seqNum, $value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ $seqNum + 1 ]{'transI'};
  $this->{'alignCol'}[ $seqNum + 1 ]{'transI'} = $value;

  return $oldValue;
}

sub getAlignedTransI
{
  my $this   = shift;
  my $seqNum = shift;

  croak $CLASS. "::getAlignedTransI( $this, $seqNum ): Index out of bounds!\n"
      if ( $seqNum < 0 || $seqNum > ( $#{ $this->{'alignCol'} } - 1 ) );

  return ( $this->{'alignCol'}[ $seqNum + 1 ]{'transI'} );
}

##---------------------------------------------------------------------##

=head2 AlignedTransV()

  Use: my $value    = getAlignedTransV( $seqNum );

  Use: my $oldValue = setAlignedTransV( $seqNum, $value );

  Get/Set the transV of an aligned sequence. The sequences are indexed from
  0 - ( $obj->getNumAlignedSeqs() - 1 ).

  NOTE: This is a replacement for the old "OBJ::transV()" method
  accept that it doesn't include access to the reference sequence.

=cut

##---------------------------------------------------------------------##
sub setAlignedTransV
{
  my $this   = shift();
  my $seqNum = shift();
  my $value  = shift();

  croak $CLASS
      . "::setAlignedTransV( $this, $seqNum, $value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ $seqNum + 1 ]{'transV'};
  $this->{'alignCol'}[ $seqNum + 1 ]{'transV'} = $value;

  return $oldValue;
}

sub getAlignedTransV
{
  my $this   = shift;
  my $seqNum = shift;

  croak $CLASS. "::getAlignedTransV( $this, $seqNum ): Index out of bounds!\n"
      if ( $seqNum < 0 || $seqNum > ( $#{ $this->{'alignCol'} } - 1 ) );

  return ( $this->{'alignCol'}[ $seqNum + 1 ]{'transV'} );
}

##---------------------------------------------------------------------##

=head2 AlignedSrcDiv()

  Use: my $value    = getAlignedSrcDiv( $seqNum );

  Use: my $oldValue = setAlignedSrcDiv( $seqNum, $value );

  Get/Set the srcDiv of an aligned sequence. The sequences are indexed from
  0 - ( $obj->getNumAlignedSeqs() - 1 ).

  NOTE: This is a replacement for the old "OBJ::srcDiv()" method
  accept that it doesn't include access to the reference sequence.

=cut

##---------------------------------------------------------------------##
sub setAlignedSrcDiv
{
  my $this   = shift();
  my $seqNum = shift();
  my $value  = shift();

  croak $CLASS
      . "::setAlignedSrcDiv( $this, $seqNum, $value ): Missing value "
      . "parameter!\n"
      if ( !defined $value );

  my $oldValue = $this->{'alignCol'}[ $seqNum + 1 ]{'srcDiv'};
  $this->{'alignCol'}[ $seqNum + 1 ]{'srcDiv'} = $value;

  return $oldValue;
}

sub getAlignedSrcDiv
{
  my $this   = shift;
  my $seqNum = shift;

  croak $CLASS. "::getAlignedSrcDiv( $this, $seqNum ): Index out of bounds!\n"
      if ( $seqNum < 0 || $seqNum > ( $#{ $this->{'alignCol'} } - 1 ) );

  return ( $this->{'alignCol'}[ $seqNum + 1 ]{'srcDiv'} );
}

##
## TODO: DEPRECATE
##
sub getAlignColArray
{
  my $this = shift();
  return $this->{'alignCol'};
}

##
## TODO: DEPRECATED
##   -- used internally
##
sub list
{
  my $object = shift;
  return $object->{'alignCol'};
}

##
## TODO: DEPRECATE
##
#sub consensusSeq
#{
#  my $object = shift;
#  @_ ? $object->{'alignCol'}[ 0 ]{seq} = shift: $object->{'alignCol'}[ 0 ]{seq};
#}

##
## TODO: DEPRECATE
##
#
# A unique identifier for this sequence within it's
# crossmatch file.
#
#sub srcAlignID
#{
#  my $object = shift;
#  @_
#      ? $object->{srcAlignID}[ 0 ]{seq} = shift
#      : $object->{'alignCol'}[ 0 ]{srcAlignID};
#}

##---------------------------------------------------------------------##

=head1 METHODS

=cut

##---------------------------------------------------------------------##

##---------------------------------------------------------------------##

=head2 getNumAlignedSeqs()

  Use: my $value = getNumAlignedSeqs( );

  Get the number of aligned sequences. 

  NOTE: This is a replacement for the old "OBJ::numSequences()" method
  accept that it doesn't include the reference sequence in 
  with the aligned sequences.

=cut

##---------------------------------------------------------------------##
sub getNumAlignedSeqs
{
  my $this = shift();

  # sequence 0 is always the reference -- don't count
  return ( $#{ $this->{'alignCol'} } );
}

#
# Return the reference position (absolute - no insertions)
# where this instance starts at.
# NOTE: Update...this now excludes the reference seq.
#       So old code will need to be updated to
#       index starting from 0 rather than 1.
#
sub instRefStart
{
  my $object = shift;
  my $n      = shift;

  croak $CLASS . "::instRefStart( $object, $n ): Index out of " . "bounds!\n"
      if (    $n < 0
           || $n > ( $#{ $object->{'alignCol'} } - 1 ) );

  my $gaps = (
               substr(
                       $object->{'alignCol'}[ 0 ]{seq},
                       0,
                       $object->{'alignCol'}[ $n + 1 ]{start}
                   ) =~ tr /-/-/
  );
  return ( ( $object->{'alignCol'}[ $n + 1 ]{start} ) - $gaps );
}

#
# Return the reference position (absolute - no insertions)
# where this instance ends at.
#
# NOTE: Update...this now excludes the reference seq.
#       So old code will need to be updated to
#       index starting from 0 rather than 1.
sub instRefEnd
{
  my $object = shift;
  my $n      = shift;

  croak $CLASS . "::instRefEnd( $object, $n ): Index out of " . "bounds!\n"
      if (    $n < 0
           || $n > ( $#{ $object->{'alignCol'} } - 1 ) );

  my $gaps = (
               substr(
                       $object->{'alignCol'}[ 0 ]{seq},
                       0,
                       $object->{'alignCol'}[ $n + 1 ]{end}
                   ) =~ tr /-/-/
  );
  return ( $object->{'alignCol'}[ $n + 1 ]{end} - $gaps );
}

## KEEP!
sub getAlignPosFromBPPos
{
  my $object = shift;
  my $pos    = shift;

  my $bpPos    = $object->getReferenceSeqStart();
  my $alignPos = 0;
  my $seqStr   = $object->getReferenceSeq();
  while ( $bpPos < $pos )
  {
    $bpPos++ if ( substr( $seqStr, $alignPos++, 1 ) ne "-" );
  }

  return $alignPos;
}

##---------------------------------------------------------------------##
## Serialization & Debug Routines
##---------------------------------------------------------------------##

##---------------------------------------------------------------------##
## Use: toString([$object]);
##
##      $object         : Normally passed implicitly
##
##  Returns
##
##      Uses the Data::Dumper to create a printable reprentation
##      of a data structure.  In this case the object data itself.
##
##---------------------------------------------------------------------##
## TODO: This could be moved into a generic object class.
##       or placed in perlhelpers module.
sub toString
{
  my $object = shift;
  my $data_dumper = new Data::Dumper( [ $object ] );
  $data_dumper->Purity( 1 )->Terse( 1 )->Deepcopy( 1 );
  return $data_dumper->Dump();
}

##---------------------------------------------------------------------##
## Use: my serializeOUT( $filename );
##
##        $filename     : A filename to be created
##
##  Returns
##
##      Uses the Data::Dumper module to save out the data
##      structure as a text file.  This text file can be
##      read back into an object of this type.
##
##---------------------------------------------------------------------##
sub serializeOUT
{
  my $object   = shift;
  my $fileName = shift;

  my $data_dumper = new Data::Dumper( [ $object ] );
  $data_dumper->Purity( 1 )->Terse( 1 )->Deepcopy( 1 );
  open OUT, ">$fileName";
  print OUT $data_dumper->Dump();
  close OUT;
}

##---------------------------------------------------------------------##
## Use: my serializeIN( $filename );
##
##      $filename       : A filename containing a serialized object
##
##  Returns
##
##      Uses the Data::Dumper module to read in data
##      from a serialized PERL object or data structure.
##
##---------------------------------------------------------------------##
sub serializeIN
{
  my $object       = shift;
  my $fileName     = shift;
  my $fileContents = "";
  my $oldSep       = $/;
  undef $/;
  my $in;
  open $in, "$fileName";
  $fileContents = <$in>;
  $/            = $oldSep;
  close $in;
  return eval( $fileContents );
}

##---------------------------------------------------------------------##
## Class Methods
##---------------------------------------------------------------------##

## None at this time.

##---------------------------------------------------------------------##
## General Object Methods
##---------------------------------------------------------------------##

##---------------------------------------------------------------------##

=head2 kimuraDivergence()

  Use: $obj->kimuraDivergence( $consensus );

=cut

##---------------------------------------------------------------------##
sub kimuraDivergence
{
  my $object           = shift;
  my $consensus        = shift;
  my $n                = 0;
  my $sumAlignedLength = 0;
  my $hits             = 0;
  my $sumDiv           = 0;

  if ( $consensus eq "" )
  {
    $consensus = $object->getReferenceSeq();
  }

  my $totDiv = 0;
  foreach $n ( 0 .. $object->getNumAlignedSeqs() - 1 )
  {
    my $alignedBases = 0;
    my $transI       = 0;
    my $transV       = 0;
    my $j            = 0;
    my $i            = 0;

    #foreach $i ( $object->start( $n ) .. $object->end( $n ) )
    foreach $i (
                $object->getAlignedStart( $n ) .. $object->getAlignedEnd( $n ) )
    {
      my $a = substr( $consensus, $i, 1 );

      #my $b = substr( $object->seq( $n ), $j, 1 );
      my $b = substr( $object->getAlignedSeq( $n ), $j, 1 );

      $j++;
      next if ( $a eq '-' || $a eq '*' );
      next if ( $b eq '-' || $b eq '*' );
      $transI++
          if (    $a . $b eq "CT"
               || $a . $b eq "TC"
               || $a . $b eq "AG"
               || $a . $b eq "GA" );
      $transV++
          if (    $a . $b eq "GT"
               || $a . $b eq "TG"
               || $a . $b eq "GC"
               || $a . $b eq "CG"
               || $a . $b eq "CA"
               || $a . $b eq "AC"
               || $a . $b eq "AT"
               || $a . $b eq "TA" );
      $alignedBases++;
    }
    $sumAlignedLength += $alignedBases;
    $hits++;
    my $p = $transI / $alignedBases;
    my $q = $transV / $alignedBases;
    if ( ( ( 1 - ( 2 * $p ) - $q ) * ( 1 - ( 2 * $q ) )**0.5 ) <= 0 )
    {
      $object->setAlignedDiv( $n, 1 );
    } else
    {
      $object->setAlignedDiv(
                              $n,
                              abs(
                                (
                                  -0.5 * log(
                                    ( 1 - ( 2 * $p ) - $q ) * ( 1 - ( 2 * $q ) )
                                        **0.5
                                  )
                                )
                              )
      );
    }
    $totDiv += $object->getAlignedDiv( $n );
    $sumDiv += ( $transI + $transV );
  }
  my $avgDiv = sprintf( "%0.2f", ( $totDiv / $hits ) );
  return ( $sumDiv, $totDiv, $avgDiv );
}

##---------------------------------------------------------------------##

=head2 divergence()

  Use: $obj->divergence( $consensus );

  Calculate the simple divergence of each hit based
  on the current consensus sequence.  NOTE: This will
  count masked sequence ("*" bases) as divergent!

=cut

##---------------------------------------------------------------------##
sub divergence
{
  my $object    = shift;
  my $consensus = shift;
  my $n         = 0;

  # No longer includes the reference sequence
  foreach $n ( 0 .. $object->getNumAlignedSeqs() - 1 )
  {
    my $total  = 0;
    my $change = 0;
    my $j      = 0;
    my $i      = 0;

    #foreach $i ( $object->start( $n ) .. $object->end( $n ) )
    foreach $i (
                $object->getAlignedStart( $n ) .. $object->getAlignedEnd( $n ) )
    {
      my $a = substr( $consensus, $i, 1 );

      #my $b = substr( $object->seq( $n ), $j, 1 );
      my $b = substr( $object->getAlignedSeq( $n ), $j, 1 );
      $j++;
      next if ( $a eq '-' );
      next if ( $b eq '-' );
      $change++ if ( $a ne $b );
      $total++;
    }
    $object->setAlignedDiv( $n, $change / $total );
  }
}

##---------------------------------------------------------------------##
## Use:   my  ($gcRemoved) = filterOnGC(  $object,
##                                        $gcLowRange,
##                                        $gcHighRange,
##                                        [$alignColID] );
##
##              $object         : This
##              $gcLowRange     : The lowest GC value acceptable
##              $gcHighRange    : Accepts sequences which are lower
##				  than this value
##              [$alignColID]   : Which alignment collection to process or
##                                undef for all.
##
##      Returns
##
##         Modifies the data structure.  It removes all sequences
##         which fall outside the GC range.
##
##---------------------------------------------------------------------##
sub filterOnGC
{
  my $this        = shift;
  my $gcLowRange  = shift;
  my $gcHighRange = shift;

  my $hit;
  my $gcRemoved = 0;
  my $deleteIndex;
  my @removalList = ();

  my $hitIndex = 0;
  foreach $hit ( @{ $this->{'alignCol'} } )
  {

    # The first sequence is the consensus so we don't want
    # to filter this out.
    if ( $hitIndex == 0 )
    {
      $hitIndex++;
      next;
    }

    #
    # Check for sequences which do not have a gcBackground value!
    #
    print "MultAln::filterOnGC: WARNING found hit without a defined "
        . "gcBackground!!!\n"
        unless ( defined $hit->{gcBackground} );
    if (    $hit->{gcBackground} < $gcLowRange
         || $hit->{gcBackground} >= $gcHighRange )
    {
      push @removalList, $hitIndex--;
      $gcRemoved++;
    }
    $hitIndex++;
  }
  foreach $deleteIndex ( @removalList )
  {
    splice @{ $this->{'alignCol'} }, $deleteIndex, 1;
  }
  @removalList = ();
  return ( $gcRemoved );
}

##---------------------------------------------------------------------##
## Use:   my  ($gcRemoved) = filterOnSrcDiv(  $object,
##                                        $divLowRange,
##                                        $divHighRange,
##                                        [$alignColID] );
##
##              $object         : This
##              $divLowRange     : The lowest divergence value acceptable
##              $divHighRange    : The highest divergence value acceptable
##              [$alignColID]   : Which alignment collection to process or
##                                undef for all.
##
##      Returns
##
##         Modifies the data structure.  It removes all sequences
##         which fall outside the divergence range. Note: Source
##	   divergence is the divergence of the hit from the source
##	   data.  It is **not** the divergence derived from the
##	   new consensus.
##
##---------------------------------------------------------------------##
sub filterOnSrcDiv
{
  my $this         = shift;
  my $divLowRange  = shift;
  my $divHighRange = shift;

  my $hit;
  my $divRemoved = 0;
  my $deleteIndex;
  my @removalList = ();

  my $hitIndex = 0;
  foreach $hit ( @{ $this->{'alignCol'} } )
  {

    # The first sequence is the reference so we don't want
    # to filter this out.
    if ( $hitIndex == 0 )
    {
      $hitIndex++;
      next;
    }

    #
    # Check for sequences which do not have a gcBackground value!
    #
    print "MultAln::filterOnSrcDiv: WARNING found hit without a defined "
        . "source divergence!!!\n"
        unless ( defined $hit->{srcDiv} );
    if (    $hit->{srcDiv} < $divLowRange
         || $hit->{srcDiv} > $divHighRange )
    {

      #print "Out of range gc=$hit->{srcDiv}\n" .
      #      "         hitIndex=$hitIndex\n";
      push @removalList, $hitIndex--;
      $divRemoved++;
    }
    $hitIndex++;
  }
  foreach $deleteIndex ( @removalList )
  {
    splice @{ $this->{'alignCol'} }, $deleteIndex, 1;
  }
  @removalList = ();
  return ( $divRemoved );
}

##---------------------------------------------------------------------##
## Use:   my  ($gcRemoved) = filterOnDiv(  $object,
##                                        $divLowRange,
##                                        $divHighRange,
##                                        [$alignColID] );
##
##              $object         : This
##              $divLowRange    : The lowest divergence value acceptable
##              $divHighRange   : The highest divergence value acceptable
##              [$alignColID]   : Which alignment collection to process or
##                                undef for all.
##
##      Returns
##
##         Modifies the data structure.  It removes all sequences
##         which fall outside the divergence range. Note: This
##	   filters on the divergence field.  This is a calculated
##	   field which is only available after the "divergence"
##	   subroutine is called.  NOTE: This field is the calculation
##	   of the divergence based on a string passed to the divergence
##	   routine and might not be based on either the source consensus
##	   or the derived consensus.
##
##---------------------------------------------------------------------##
sub filterOnDiv
{
  my $this         = shift;
  my $divLowRange  = shift;
  my $divHighRange = shift;

  my $hit;
  my $divRemoved = 0;
  my $deleteIndex;
  my @removalList = ();

  my $hitIndex = 0;
  foreach $hit ( @{ $this->{'alignCol'} } )
  {

    # The first sequence is the consensus so we don't want
    # to filter this out.
    if ( $hitIndex == 0 )
    {
      $hitIndex++;
      next;
    }

    #
    # Check for sequences which do not have a gcBackground value!
    #
    print "MultAln::filterOnDiv: WARNING found hit without a defined "
        . "source divergence!!!\n"
        unless ( defined $hit->{div} );
    if (    $hit->{div} < $divLowRange
         || $hit->{div} > $divHighRange )
    {

      #print "Out of range gc=$hit->{div}\n" .
      #      "         hitIndex=$hitIndex\n";
      push @removalList, $hitIndex--;
      $divRemoved++;
    }
    $hitIndex++;
  }
  foreach $deleteIndex ( @removalList )
  {
    splice @{ $this->{'alignCol'} }, $deleteIndex, 1;
  }
  @removalList = ();
  return ( $divRemoved );
}

##---------------------------------------------------------------------##
## Use: alignFromCrossMatchFile($file, $searchCollectionReference,
##                              $serialized);
##
##
## DEPRECATED!  This function is only in place to support old
## code which still calls this.  Do not use this anymore.  Instead
## instantiate this object with a SearchResultCollection.pm
##
##---------------------------------------------------------------------##
sub alignFromCrossMatchFile
{
  my $object                    = shift;
  my $file                      = shift;
  my $searchCollectionReference = shift;
  my $serialized                = shift;

  print "NOTE: This function is obsolete and should be "
      . "replaced with a call to: alignFromSearchResultCollection\n";

  #
  # Instantiate a SearchResultCollection object and load
  # from it.
  #
  my $searchResultCol =
      CrossmatchSearchEngine->parseOutput( searchOutput => $file );
  croak $CLASS
      . "::alignFromCrossMatchFile(): This function no "
      . "accepts the serialized parameter. In fact this function "
      . "is obsolete.  You should switch to using search result "
      . "collections.\n"
      if ( $serialized );
  if ( uc( $searchCollectionReference ) eq "QUERY" )
  {
    alignFromSearchResultCollection(
                                     searchCollection  => $searchResultCol,
                                     referenceSequence => "",
                                     searchCollectionReference => MultAln::Query
    );
  } else
  {
    alignFromSearchResultCollection(
                                   searchCollection  => $searchResultCol,
                                   referenceSequence => "",
                                   searchCollectionReference => MultAln::Subject
    );
  }
}

##---------------------------------------------------------------------##
## Use: _alignFromSearchResultCollection( $this,
##                                     searchCollection => ref,
##                                     referenceSequence => "ACCA..AACC"
##                                     [searchCollectionReference =>
##                                                      MultAln::Query |
##                                                      MultAln::Subject],
##                                     [flankingSequenceDatabase => xxx,
##                                      [maxFlankingSequenceLen => ] ]);
##
##
## This is a private method for generating a multiple alignment from
## a search result collection containing a search of one sequence
## against many others.
##
##---------------------------------------------------------------------##
sub _alignFromSearchResultCollection
{
  my $object     = shift;
  my %parameters = @_;

  # Parameter validation
  croak $CLASS
      . "::alignFromSearchResultCollection() searchCollection "
      . "parameter is missing or is of the wrong type: "
      . ref( $parameters{'searchCollection'} ) . "\n"
      if ( ref( $parameters{'searchCollection'} ) ne "SearchResultCollection" );
  my $searchCollection = $parameters{'searchCollection'};

  # Which sequence (Query/Subject) represents the reference
  # sequence and which one represents the instance sequences.
  my $orientationMatters = 0;
  my $refStart           = "getQueryStart";
  my $refEnd             = "getQueryEnd";
  my $refSeq             = "getQueryString";
  my $refName            = "getQueryName";
  my $refRemaining       = "getQueryRemaining";
  my $instStart          = "getSubjStart";
  my $instEnd            = "getSubjEnd";
  my $instSeq            = "getSubjString";
  my $instName           = "getSubjName";
  my $instRemaining      = "getSubjRemaining";
  if ( defined $parameters{'searchCollectionReference'} )
  {
    croak $CLASS
        . "::alignFromSearchResultCollection() "
        . "searchCollectionReference parameter is not recognized ( "
        . $parameters{'searchCollectionReference'}
        . " should be either MultAln::Query or MultAln::Subject!\n"
        if (    $parameters{'searchCollectionReference'} != MultAln::Query
             && $parameters{'searchCollectionReference'} != MultAln::Subject );
    if ( $parameters{'searchCollectionReference'} == MultAln::Subject )
    {
      $refStart           = "getSubjStart";
      $refEnd             = "getSubjEnd";
      $refSeq             = "getSubjString";
      $refName            = "getSubjName";
      $refRemaining       = "getSubjRemaining";
      $instStart          = "getQueryStart";
      $instEnd            = "getQueryEnd";
      $instSeq            = "getQueryString";
      $instName           = "getQueryName";
      $instRemaining      = "getQueryRemaining";
      $orientationMatters = 1;
    }
  }

  croak $CLASS
      . "::alignFromSearchResultCollection(): The search "
      . "result collection must contain at least one alignment!"
      if ( $searchCollection->size() < 1 );

  #
  #  To Complement or Not to Complement:
  #    We are using the SearchResultsCollection object here.
  #    This object makes the promise that query sequences are
  #    always oriented to be on the forward strand.  The subject
  #    strand may or may not be complemented ( based on the orientation
  #    property ).  Since we are only concerned about character
  #    matching we do not need to correct the sequence before
  #    proceding....but we do save the orientation in case anyone
  #    else wants to know.
  if ( $orientationMatters )
  {
    my $newSearchResultCollection = SearchResultCollection->new();
    for ( my $i = 0 ; $i < $searchCollection->size() ; $i++ )
    {
      my $result = $searchCollection->get( $i )->clone();
      if ( $result->getOrientation eq "C" )
      {
        my $str = uc( $result->getSubjString() );
        $str = reverse( $str );
        $str =~ tr/ACGTYRMKHBVD/TGCARYKMDVBH/;
        $result->setSubjString( $str );

        $str = uc( $result->getQueryString() );
        $str = reverse( $str );
        $str =~ tr/ACGTYRMKHBVD/TGCARYKMDVBH/;
        $result->setQueryString( $str );
      }
      $newSearchResultCollection->add( $result );
    }
    $searchCollection = $newSearchResultCollection;
  }

  #
  # Build the reference sequence
  #
  my $combRefSeq = "";
  my $tRemaining = 0;
  my $tMin;
  my $tMax;
  if ( !defined $parameters{'referenceSeq'}
       || $parameters{'referenceSeq'} eq "" )
  {

    #
    #   Form a combined reference sequence from all
    #   alignments.
    #
    $tMin = $searchCollection->get( 0 )->$refStart();
    $tMax = $searchCollection->get( 0 )->$refEnd();
    for ( my $i = 1 ; $i < $searchCollection->size() ; $i++ )
    {
      my $start = $searchCollection->get( $i )->$refStart();
      my $end   = $searchCollection->get( $i )->$refEnd();
      $tMin = $start if ( $start < $tMin );
      if ( $end > $tMax )
      {
        $tMax       = $end;
        $tRemaining = $searchCollection->get( $i )->$refRemaining();
      }
    }
    $combRefSeq = ' ' x ( $tMax - $tMin + 1 );
    my $combRefSeqLen = ( $tMax - $tMin + 1 );
    for ( my $i = 0 ; $i < $searchCollection->size() ; $i++ )
    {
      my $seq = $searchCollection->get( $i )->$refSeq();
      $seq =~ s/-//g;
      my $len = length $seq;
      my $ts  = $searchCollection->get( $i )->$refStart();
      substr( $combRefSeq, $ts - $tMin, $len ) = $seq;
    }
    if ( $combRefSeq =~ /\s+/ )
    {
      warn $CLASS
          . "::_alignFromSearchResultCollection: Reference "
          . "sequence is incomplete.  No coverage is available for "
          . "at least one subregion of "
          . $searchCollection->get( 0 )->$refName() . ".\n";
    }
  } else
  {

    #
    # Get reference sequence from parameters
    #
    $combRefSeq = $parameters{'referenceSeq'};
    $tMin       = 1;
    $tMax       = length( $combRefSeq );
  }
  print $CLASS
      . "::_alignFromSearchResultCollection: Combined "
      . "reference sequence = $combRefSeq\n"
      if ( $DEBUG );

  #
  #   Form gap pattern arrays for both query and subject sequences:
  #   The gap pattern array of sequence is the array @gap defined by:
  #       $gap[i] = number of gaps between positions prior to i in the
  #                 sequence;
  #   Here @gapPattern[$i] is the gap pattern for $xm->targetSeq($i) and
  #   @refGapPattern is the gap pattern for $refSeq
  #
  #   EXAMPLE:
  #      gapped seq: --ACGC--GCA---CGGTGC-CGT-C-
  #      sequence:   ACGCGCACGGTGCCGTC
  #      gapPattern: 200020030000010011
  #
  #   The gaps prior/following the sequence allow for use with
  #   a global alignment dataset.
  #
  my $i          = 0;
  my @gapPattern = ();
  for ( my $l = 0 ; $l < $searchCollection->size() ; $l++ )
  {
    my $result = $searchCollection->get( $l );
    my @unGaps = split( /[^-]/, $result->$refSeq() );

    # For gap after base
    #shift @unGaps;
    $gapPattern[ $i ] = [ map ( length, @unGaps ) ];
    my $t = $result->$refStart() - $tMin;
    unshift @{ $gapPattern[ $i++ ] }, ( 0 ) x $t;
  }

  #
  # Find the max gapPattern from all the gapPatterns:
  #    ie   0002003000100
  #         0102002000800
  #         0005001000800
  #         -------------
  #    max  0105003000800
  #
  my $len           = length( $combRefSeq );
  my $j             = 0;
  my @refGapPattern = ();
  foreach $j ( 0 .. $len )
  {
    $refGapPattern[ $j ] = 0;
    foreach $i ( 0 .. $searchCollection->size() - 1 )
    {
      next if ( !defined $gapPattern[ $i ][ $j ] );
      $refGapPattern[ $j ] = $gapPattern[ $i ][ $j ]
          if ( $gapPattern[ $i ][ $j ] > $refGapPattern[ $j ] );
    }
  }

  #
  # Create the relevant gaps in the reference
  # sequence
  #
  my $seq = '';
  foreach $j ( 0 .. $len - 1 )
  {

    # Reversed the order of these
    $seq .= '-' x $refGapPattern[ $j ];
    $seq .= substr( $combRefSeq, $j, 1 );
  }
  $seq .= '-' x $refGapPattern[ $len ]
      if ( defined $refGapPattern[ $len ] );

  #
  #
  #
  $object->setReferenceSeq( $seq );

  # Do we need to set these anyway?
  #$object->start( 0, 0 );
  #$object->end( 0, ( $object->getGappedReferenceLength() ) - 1 );
  # TODO: Since this should be strand independant should this be
  #       the name of the query?
  #$object->name( 0, $searchCollection->get( 0 )->$refName() );
  $object->setReferenceName( $searchCollection->get( 0 )->$refName() );

  #$object->seqStart( 0, $tMin );
  $object->setReferenceSeqStart( $tMin );

  #
  #   compute the start of each alignment relative to the start
  #   of the reference seq
  #
  #   $totalGaps[$j] = the total number of gaps prior to position $j
  #   in the reference sequence
  #
  my @totalGaps;
  $totalGaps[ 0 ] = 0;
  foreach $j ( 1 .. $len )
  {
    $totalGaps[ $j ] = $totalGaps[ $j - 1 ] + $refGapPattern[ $j - 1 ];
  }

  for ( my $l = 0 ; $l < $searchCollection->size() ; $l++ )
  {
    my $result = $searchCollection->get( $l );
    my $start  = $result->$refStart() - $tMin;
    $start += $totalGaps[ $start ];
    $object->setAlignedStart( $l, $start );
    my $seq = '';
    my $len = length( $result->$instSeq() );
    my $k   = $result->$refStart() - $tMin;    # position in ungapped ref
    foreach $j ( 0 .. $len )
    {
      my $n = substr( $result->$instSeq(), $j, 1 );
      my $a = substr( $result->$refSeq(),  $j, 1 );
      if ( $a ne '-' )
      {
        my $numgaps = $refGapPattern[ $k ];
        $numgaps -= $gapPattern[ $l ][ $k ]
            if ( defined $gapPattern[ $l ][ $k ] );
        $seq .= '-' x $numgaps;
        $k++;
      }
      $seq .= $n;
    }
    $object->setAlignedSeq( $l, $seq );
    $len = length $seq;
    $object->setAlignedEnd( $l, $start + $len - 1 );
    $object->setAlignedName( $l, $result->$instName() );
    $object->setAlignedSeqStart( $l, $result->$instStart() );
    $object->setAlignedSrcDiv( $l, $result->getPctDiverge() );
    if ( $parameters{'searchCollectionReference'} == MultAln::Subject )
    {

      # The reference orientation is variable if it's source
      # is the subject side of a SearchResultCollection.  Thus
      # we must set it accordingly.
      # TODO: Set the Reference Orientation.

      # Since the aligned sequence's source is the query side
      # of the SearchResultCollection we can assume it's always
      # forward strand.
      $object->setAlignedOrientation( $l, "+" );
    } else
    {

      # TODO: Set the Reference Orientation ( constant forward ).
      if ( $result->getOrientation() eq "C" )
      {
        $object->setAlignedOrientation( $l, "-" );
      } else
      {
        $object->setAlignedOrientation( $l, "+" );
      }
    }
  }

  # Lastly lets load in the flanking sequences if we are given
  # the chance.
  if ( defined $parameters{'flankingSequenceDatabase'} )
  {
    my $seqDB = $parameters{'flankingSequenceDatabase'};

    # Set the max flanking length
    my $maxLen = MaxFlankingSeqLen;
    if ( defined $parameters{'maxFlankingSequenceLen'} )
    {
      if ( $parameters{'maxFlankingSequenceLen'} > 0 )
      {
        $maxLen = $parameters{'maxFlankingSequenceLen'};
      } else
      {
        $maxLen = -1;
      }
    }

    # Grab the reference flanking sequence
    my $seqID        = $object->getReferenceName();
    my $seqStart     = $tMin;
    my $seqEnd       = $tMax;
    my $seqRemaining = $tRemaining;
    if ( $seqDB->getSeqLength( $seqID ) > 0 )
    {

      # Determine the left boundaries
      my $end   = $seqStart - 1;
      my $start = 0;
      if ( $maxLen > -1 )
      {
        $start = $seqStart - $maxLen if ( $seqStart > $maxLen );
      }
      $object->setLeftFlankingSequence(
                                        0,
                                        $seqDB->getSubstr(
                                                   $seqID, $start, $end - $start
                                        )
      );

      # Determine the right boundaries
      $start = $seqEnd + 1;
      $end   = $seqEnd + $seqRemaining;
      if ( $maxLen > -1 )
      {
        $end = $end - $maxLen if ( $seqRemaining > $maxLen );
      }
      $object->setRightFlankingSequence( 0,
                       $seqDB->getSubstr( $seqID, $start, $end - $start - 1 ) );
    }

    # Grab the instance flanking sequence
    for ( my $l = 0 ; $l < $searchCollection->size() ; $l++ )
    {
      my $result = $searchCollection->get( $l );
      $seqID        = $result->$instName();
      $seqStart     = $result->$instStart();
      $seqEnd       = $result->$instEnd();
      $seqRemaining = $result->$instRemaining();
      if ( $seqDB->getSeqLength( $seqID ) > 0 )
      {

        # Determine the left boundaries
        my $end   = $seqStart - 1;
        my $start = 0;
        if ( $maxLen > -1 )
        {
          $start = $seqStart - $maxLen if ( $seqStart > $maxLen );
        }
        $object->setLeftFlankingSequence( $l + 1,
                           $seqDB->getSubstr( $seqID, $start, $end - $start ) );

        # Determine the right boundaries
        $start = $seqEnd;
        $end   = $seqEnd + $seqRemaining;
        if ( $maxLen > -1 )
        {
          $end = $end - $maxLen if ( $seqRemaining > $maxLen );
        }
        $object->setRightFlankingSequence( $l + 1,
                           $seqDB->getSubstr( $seqID, $start, $end - $start ) );

      }
    }
  }

}

##---------------------------------------------------------------------##

=head2 getLowScoringAlignmentColumns()


  Use: my ( $columns, $valArray) = getLowScoringAlignmentColumns( 
                                       matrix => MATRIXREF,
                                       gapInitiationPenalty => SCALAR,
                                       gapExtensionPenalty => SCALAR,
                                       threshold => SCALAR 
                                                                );


      matrix               : A reference to a SequenceSimilarityMatrix
                              object.
      gapInitiationPenalty : The penalty to initiate a gap.
      gapExtensionPenalty  : The penalty to extend a gap.
      threshold            : The maximum score for which to report
                              low scoring blocks.
      columns              : A collection of low scoring columns
                              with start/end position:
                              startPosition = 
                                $columns->[ 0-numColumns ]->[ 0 ]
                              endPosition = 
                                $columns->[ 0-numColumns ]->[ 1 ]
      valArray             : A reference to an array of block scores
                              across the reference sequence.

  Find all the low scoring blocks within the multiple alignment.  
  The low scoring subsequences are found using the Ruzzo & Tompa 
  algorithm: "A Linear Time Algorithm For Finding All Maximal Scoring 
  Subsequences".  The multiple alignment is processed into a single 
  score array over the reference sequence using the given matrix and 
  gap initiation/extension penalties.  The score is inverted so as 
  to give the minimal scoring subsequences below the given threshold.

=cut

##---------------------------------------------------------------------##
sub getLowScoringAlignmentColumns
{
  my $this           = shift;
  my %nameValuePairs = @_;

  my @columns        = ();
  my $gapOpenPenalty = -40;
  if ( defined $nameValuePairs{'gapInitiationPenalty'} )
  {
    $gapOpenPenalty = $nameValuePairs{'gapInitiationPenalty'};
  }
  my $gapExtPenalty = -15;
  if ( defined $nameValuePairs{'gapExtensionPenalty'} )
  {
    $gapExtPenalty = $nameValuePairs{'gapExtensionPenalty'};
  }
  my $threshold = 1;
  if ( defined $nameValuePairs{'threshold'} )
  {
    $threshold = $nameValuePairs{'threshold'};
  }
  my $matrix_r;
  if ( defined $nameValuePairs{'matrix'}
       && ref( $nameValuePairs{'matrix'} ) eq "SequenceSimilarityMatrix" )
  {
    my $matrix = $nameValuePairs{'matrix'};
    $matrix_r = $matrix->{'matrixHash'};
  } else
  {
    ## Reasonable defaults
    ## TODO: Encode these default matrices somewhere centrally -- perhaps in matrix.pm
    # Comparison Matrix
    #  A   R   G   C   Y   T   K   M   S   W   N
    my @alphaArray = (
                       qw(   9   1  -6 -15 -16 -17 -12  -2 -10  -4  -1 ),
                       qw(   1   1   1 -15 -15 -16  -6  -6  -6  -7  -1 ),
                       qw(  -6   1  10 -15 -15 -15  -2  -10 -2  -10 -1 ),
                       qw( -15 -15 -15  10   2  -6  -9  -2  -2  -9  -1 ),
                       qw( -16 -15 -15   1   1   1  -6  -7  -7  -7  -1 ),
                       qw( -17 -16 -15  -6   1   9  -2 -12 -11  -4  -1 ),
                       qw( -12  -6  -2 -11  -6  -2  -2 -11  -7  -7  -1 ),
                       qw(  -2  -6 -10  -2  -7 -12 -11  -2  -7  -7  -1 ),
                       qw(  -10 -6  -2  -2  -7 -11  -7  -7  -2  -10 -1 ),
                       qw(  -4  -7 -10 -11  -7  -4  -7  -7 -10  -4  -1 ),
                       qw(  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1  -1 )
    );

    my $alphabet_r = [ qw( A   R   G   C   Y   T   K   M   S   W   N ) ];
    $matrix_r = {};
    for ( my $i = 0 ; $i < scalar( @{$alphabet_r} ) ; $i++ )
    {
      for ( my $j = 0 ; $j < scalar( @{$alphabet_r} ) ; $j++ )
      {
        $matrix_r->{ $alphabet_r->[ $i ], $alphabet_r->[ $j ] } =
            $alphaArray[ ( $i * scalar( @{$alphabet_r} ) ) + $j ];
      }
    }
  }

  my @profile   = ();
  my @posCounts = ();
  for ( my $seqNum = 0 ; $seqNum < $this->getNumAlignedSeqs ; $seqNum++ )
  {

    #my $subjSeq  = $this->seq( $seqNum );
    my $subjSeq = $this->getAlignedSeq( $seqNum );

    #my $querySeq =
    #    substr( $this->seq( 0 ), $this->start( $seqNum ), length( $subjSeq ) );
    my $querySeq = substr( $this->getReferenceSeq(),
                           $this->getAlignedStart( $seqNum ),
                           length( $subjSeq ) );
    my $inGap = 0;
    for ( my $j = 0 ; $j < length( $querySeq ) ; $j++ )
    {
      my $trgBase = substr( $subjSeq,  $j, 1 );
      my $refBase = substr( $querySeq, $j, 1 );
      if (    ( $refBase eq "-" && $trgBase ne "-" )
           || ( $refBase ne "-" && $trgBase eq "-" ) )
      {
        if ( $inGap )
        {
          $profile[ $j + $this->getAlignedStart( $seqNum ) ] += $gapExtPenalty;
          $posCounts[ $j + $this->getAlignedStart( $seqNum ) ]++;
        } else
        {
          $profile[ $j + $this->getAlignedStart( $seqNum ) ] += $gapOpenPenalty;
          $posCounts[ $j + $this->getAlignedStart( $seqNum ) ]++;
          $inGap = 1;
        }
      } elsif ( $refBase eq "-" && $trgBase eq "-" )
      {
        $posCounts[ $j + $this->getAlignedStart( $seqNum ) ]++;
      } else
      {
        $profile[ $j + $this->getAlignedStart( $seqNum ) ] +=
            $matrix_r->{ $refBase, $trgBase };
        $posCounts[ $j + $this->getAlignedStart( $seqNum ) ]++;
        $inGap = 0;
      }
    }
  }

  for ( my $j = 0 ; $j <= $#posCounts ; $j++ )
  {
    if ( $posCounts[ $j ] > 0 )
    {
      $profile[ $j ] = $profile[ $j ] / $posCounts[ $j ];
    }
  }

  #
  # To search for worst scoring regions we first must
  # calculate the inverse of the profile signs.
  #
  foreach my $index ( 0 .. $#profile )
  {
    $profile[ $index ] *= -1;
  }

  my $valArray = _ruzzoTompaFindAllMaximalScoringSubsequences( \@profile );

  # Calc the average
  my @seqPosAvg = @{$valArray};

  # Find low quality columns
  my $inCol    = 0;
  my $colStart = -1;
  for ( my $i = 0 ; $i <= $#seqPosAvg ; $i++ )
  {
    if ( $seqPosAvg[ $i ] >= $threshold )
    {
      if ( $colStart == -1 )
      {
        $inCol    = 1;
        $colStart = $i;
      }
    } elsif ( $inCol == 1 )
    {
      $inCol = 0;
      push @columns, [ $colStart, $i - 1 ];
      $colStart = -1;
    }
  }
  if ( $inCol == 1 )
  {
    push @columns, [ $colStart, $#seqPosAvg ];
  }

  return ( \@columns, $valArray );
}

##---------------------------------------------------------------------##

=head2 getAlignmentBlock()

  Use: \@results = getAlignmentBlock( start => $start,
                                      end   => $end,
                                     [rawSequences => 1] );

  Get an array of sequences ( including gaps if rawSequences
  is undefined ) which represents a slice of the multiple
  alignment.

  NOTE: This at one time included the reference sequence.
        Currently it does not.

=cut

##---------------------------------------------------------------------##
sub getAlignmentBlock
{
  my $this       = shift;
  my %parameters = @_;

  croak $CLASS. "::getAlignmentBlock(): Missing start parameter!\n"
      if ( !defined $parameters{'start'} );
  my $start = $parameters{'start'};

  croak $CLASS. "::getAlignmentBlock(): Missing end parameter!\n"
      if ( !defined $parameters{'end'} );
  my $end = $parameters{'end'};

  my @results = ();
  for ( my $j = 0 ; $j < $this->getNumAlignedSeqs() ; $j++ )
  {
    if (    $start >= $this->getAlignedStart( $j )
         && $end <= $this->getAlignedEnd( $j ) )
    {
      if ( defined $parameters{'rawSequences'} )
      {

        #my $seq = substr( $this->seq( $j ),
        #                  $start - $this->start( $j ),
        #                  $end - $start + 1 );
        my $seq = substr( $this->getAlignedSeq( $j ),
                          $start - $this->getAlignedStart( $j ),
                          $end - $start + 1 );
        $seq =~ s/-//g;
        push @results, $seq;
      } else
      {
        push @results,

            #substr( $this->seq( $j ),
            #        $start - $this->start( $j ),
            #        $end - $start + 1 );
            substr( $this->getAlignedSeq( $j ),
                    $start - $this->getAlignedStart( $j ),
                    $end - $start + 1 );
      }
    }
  }

  return ( shift @results, \@results );

}

##---------------------------------------------------------------------##
## Use: \@results =  _ruzzoTompaFindAllMaximalScoringSubsequences (
##                                                 @sequenceScoreArray
##                                                                );
##      @sequenceScoreArray : An array containing individual
##                            penalty scores for each position
##                            within the sequence.
##
##  Returns
##      An implementation of an algorithm by Walter Ruzzo and Martin
##      Tompa ("A Linear Time Algorithm for Finding All Maximal Scoring
##      Subsequences" - 7th Intl Conf. Intelligent Systems for Mol
##      Biology).
##
##      The result is an array the size of the original sequence.
##      The array is annotated as follows:
##
##          Subsequences:   Each position within the subsequence is
##                          replaced with the subsequences' score.
##                          NOTE: It is not possible for two subsequences
##                          with the same score to adjacent to one another.
##                          ( See algorithm paper ).
##          Other       :   Contains the number zero.
##
##---------------------------------------------------------------------##
sub _ruzzoTompaFindAllMaximalScoringSubsequences
{
  my @b = @{ shift() };

  #
  # Data Structures
  #
  my @I = ();
  my @L = ();
  my @R = ();
  my @S = ();

  #
  # Seeds
  #
  my $i        = 0;
  my $j        = 0;
  my $subStart = -1;

  #
  # Maximal scoring subsequences
  #
  while ( $i <= $#b )
  {

    # Cumulative Scores Array
    if ( $i > 0 )
    {
      $S[ $i ] = $S[ $i - 1 ] + $b[ $i ];
    } else
    {
      $S[ $i ] = $b[ $i ];
    }

    # Only consider positive scores
    if ( $b[ $i ] > 0 )
    {

      # Subsequence start pointer
      $subStart = $i if ( $subStart == -1 );

      # Step 1: Find the maximal j for which Lj < Lk
      for ( $j = $#L ; $j >= 0 ; $j-- )
      {
        last if ( $L[ $j ] < $S[ $subStart - 1 ] );
      }

      # Step 2,3:
      if (    $L[ $j ] > $S[ $subStart - 1 ]
           || $#L == -1
           || $j == -1
           || $R[ $j ] >= $S[ $i ] )
      {
        push @I, [ $subStart, $i ];
        if ( $i == 0 ) { push @L, 0; }
        else { push @L, $S[ $subStart - 1 ]; }
        push @R, $S[ $i ];
        $subStart = -1;
        $i++;
      } else
      {

        # Step 4:
        $subStart = $I[ $j ][ 0 ];
        foreach ( $j .. $#I ) { pop @I; pop @L; pop @R; }

      }

    } else
    {
      $i++;
    }
  }

  #
  # Build array
  #
  my @results = ( 0 ) x ( $#b + 1 );

  foreach $i ( 0 .. $#I )
  {
    foreach $j ( $I[ $i ][ 0 ] .. $I[ $i ][ 1 ] )
    {
      $results[ $j ] = ( $R[ $i ] - $L[ $i ] );
    }
  }
  return ( \@results );

}

##---------------------------------------------------------------------##
##
## Use _getSequenceDuplicates()
##
## Private method
##
##---------------------------------------------------------------------##
sub _getSequenceDuplicates
{
  my $this = shift;

  print "_getSequenceDuplicates\n" if ( $DEBUG );

  # Collect similar names into a hash pointing to arrays of index
  my %nameHash = ();
  for ( my $i = 0 ; $i < $this->getNumAlignedSeqs ; $i++ )
  {
    push @{ $nameHash{ $this->getAlignedName( $i ) } }, $i;
  }

  # Find all multiply occuring names
  foreach my $name ( keys( %nameHash ) )
  {
    if ( $#{ $nameHash{$name} } == 0 )
    {
      delete $nameHash{$name};
    }
  }

  print "_getSequenceDuplicates: " . keys( %nameHash ) . " dups\n"
      if ( $DEBUG );
  return ( \%nameHash );
}

sub _pickHistogramPeak
{
  my %parameters = @_;

  my $histoArray = $parameters{'histogram'};
  my $windowSize = $parameters{'windowSize'};

  #croak $CLASS."::_pickHistogramPeak(): Histogram is not as wide as ".
  #      "the window size!\n" if ( ( $#{ $histoArray } + 1 ) <
  #                                $windowSize-1;
  my $useHighestInWindow = $parameters{'useHighestInWindow'};

  my $prevScore          = 0;
  my $score              = 0;
  my $highScore          = 0;
  my $highScoreStart     = -1;
  my $highScoreEnd       = -1;
  my $windowFlankingSize = ( ( $windowSize - 1 ) / 2 );
  for ( my $i = 0 ; $i <= $windowFlankingSize ; $i++ )
  {
    print "Histo:  $i -> " . $histoArray->[ $i ] . "\n"
        if ( $histoArray->[ $i ] > 0 && $DEBUG );
    $score += $histoArray->[ $i ];
  }
  my $i;
  for ( $i = $windowFlankingSize + 1 ; $i <= $#{$histoArray} ; $i++ )
  {
    print "Histo: $i -> " . $histoArray->[ $i ] . "\n"
        if ( $histoArray->[ $i ] > 0 && $DEBUG );
    $score += $histoArray->[ $i ];
    if ( $i - $windowSize >= 0 )
    {
      $score -= $histoArray->[ $i - $windowSize ];
    }
    if ( $score > $highScore )
    {
      $highScoreStart = $i - $windowFlankingSize - 1;
      $highScore      = $score;
    }
    if ( $score < $prevScore && $prevScore == $highScore )
    {
      $highScoreEnd = $i - 1;
    }
    $prevScore = $score;
  }
  $highScoreEnd = $i - 1 if ( $highScoreEnd < $highScoreStart );
  if ( $useHighestInWindow == 1 )
  {
    my $maxPos = 0;
    my $maxVal = 0;
    print "About to call $highScoreStart to $highScoreEnd\n";
    for ( my $i = $highScoreStart ; $i <= $highScoreEnd ; $i++ )
    {
      if ( $histoArray->[ $i ] > $maxVal )
      {
        $maxVal = $histoArray->[ $i ];
        $maxPos = $i;
      }
    }
    return ( $highScore, $maxPos );
  } else
  {
    return (
             $highScore,
             $highScoreStart + (
                     sprintf( "%0.0f", ( $highScoreEnd - $highScoreStart ) / 2 )
             )
    );
  }
}

##---------------------------------------------------------------------##
##
## Use: _pickHistogramPeaks(..);
##
## Private method.
##
##---------------------------------------------------------------------##
sub _pickHistogramPeaks
{
  my $this       = shift;
  my %parameters = @_;

  my $histoArray  = $parameters{'histogram'};
  my $windowSize  = $parameters{'windowSize'};
  my $threshold   = $parameters{'threshold'};
  my $perPosCount = $parameters{'perPosCount'};

  #croak $CLASS."::_pickHistogramPeak(): Histogram is not as wide as ".
  #      "the window size!\n" if ( ( $#{ $histoArray } + 1 ) <
  #                                $windowSize-1;
  my $useHighestInWindow = $parameters{'useHighestInWindow'};

  my $score              = 0;
  my $peakHighScore      = 0;
  my $peakPos            = -1;
  my $inPeak             = 0;
  my $peakWindowStart    = -1;
  my @peakList           = ();
  my $windowFlankingSize = ( ( $windowSize - 1 ) / 2 );

  my %windowNameHash = ();
  for ( my $i = 0 ; $i < $windowFlankingSize ; $i++ )
  {
    print "Histo:  $i -> " . $histoArray->[ $i ] . "\n"
        if ( $histoArray->[ $i ] > 0 && $DEBUG );
    $score += $histoArray->[ $i ];
    for ( my $j = 0 ; $j < $this->getNumAlignedSeqs() ; $j++ )
    {
      if ( $this->instRefStart( $j ) == $i )
      {
        $windowNameHash{ $this->getAlignedName( $j ) }++;
      }
    }
  }

  my $i                 = -1;
  my $numUniqSequences  = -1;
  my $sig               = -1;
  my $distSinceLastCall = $windowFlankingSize;
  for ( $i = 0 ; $i <= $#{$histoArray} ; $i++ )
  {
    my $windowStart = $i - $windowFlankingSize;
    my $windowEnd   = $i + $windowFlankingSize;
    $distSinceLastCall++;

    # Slide Score Window
    if ( $windowEnd <= $#{$histoArray} )
    {

      # Add new column
      $score += $histoArray->[ $windowEnd ];
    }
    if ( ( $windowStart - 1 ) >= 0 )
    {

      # Remove old column
      $score -= $histoArray->[ $windowStart - 1 ];
    }

    # Slide Uniq Sequence Window
    for ( my $j = 0 ; $j < $this->getNumAlignedSeqs ; $j++ )
    {
      if ( $this->instRefStart( $j ) == $windowEnd )
      {
        $windowNameHash{ $this->getAlignedName( $j ) }++;
      } elsif ( $this->instRefEnd( $j ) == ( $windowStart - 1 ) )
      {
        $windowNameHash{ $this->getAlignedName( $j ) }--;
        if ( $windowNameHash{ $this->getAlignedName( $j ) } == 0 )
        {
          delete $windowNameHash{ $this->getAlignedName( $j ) };
        }
      }
    }
    $numUniqSequences = scalar( keys( %windowNameHash ) );
    $sig              = 0;
    if ( $numUniqSequences >= 3 )
    {
      $sig = sprintf( "%0.2f", $score / $numUniqSequences );
    }

    print "Histo: $i -> "
        . $histoArray->[ $i ]
        . " window[ $windowStart<-$i->$windowEnd ]"
        . "=$score aligns\@pos = $numUniqSequences"
        . " ... sig=$sig\n"
        if ( $histoArray->[ $i ] > 0 && $DEBUG );

    if (    $inPeak == 0
         && $sig > 0.5
         && $distSinceLastCall > $windowFlankingSize )
    {
      print "Entering Peak score = $score aligns\@pos = $numUniqSequences "
          . " sig = $sig\n"
          if ( $DEBUG );
      $peakWindowStart = 0;
      $peakWindowStart = $windowStart if ( $windowStart >= 0 );
      $inPeak          = 1;
    }

    if ( $inPeak == 1 && $sig <= 0.5 )
    {
      print "Leaving Peak score = $score aligns\@pos = $numUniqSequences "
          . " sig = $sig\n"
          if ( $DEBUG );

      # emit a peak
      my $max    = 0;
      my $maxPos = -1;
      print "Calculating high score from $peakWindowStart to $i\n"
          if ( $DEBUG );
      for ( my $j = $peakWindowStart ; $j <= $i ; $j++ )
      {
        if ( $max < $histoArray->[ $j ] )
        {
          $max    = $histoArray->[ $j ];
          $maxPos = $j;
        }
      }
      push @peakList,
          {
            'pos'   => $maxPos,
            'score' => $peakHighScore
          };
      $inPeak            = 0;
      $distSinceLastCall = 0;
      $peakHighScore     = -1;
    }
    if ( $inPeak == 1 && $peakHighScore < $score )
    {
      $peakHighScore = $score;
    }
  }

  # Trailing case
  if ( $inPeak == 1 )
  {
    print "Leaving Peak score = $score aligns\@pos = $numUniqSequences "
        . " sig = $sig\n"
        if ( $DEBUG );

    # emit a peak
    my $max    = 0;
    my $maxPos = -1;
    print "Calculating high score from $peakWindowStart to $i\n" if ( $DEBUG );
    for ( my $j = $peakWindowStart ; $j <= $i ; $j++ )
    {
      if ( $max < $histoArray->[ $j ] )
      {
        $max    = $histoArray->[ $j ];
        $maxPos = $j;
      }
    }
    push @peakList,
        {
          'pos'   => $maxPos,
          'score' => $peakHighScore
        };
  }
  return \@peakList;
}

##---------------------------------------------------------------------##

=head2 _getEndStartPairs()

   Use: my = _getEndStartPairs( .. );

   THIS IS A PROTOTYPE!!!

   Deletion Scenario
   =================

    Biological intuition:
      A repeat incurs a large deletion shortly after it begins
      copying in the genome.  Most copies are not missing the deleted
      sequence. The problem occurs when a reference is chosen which
      *is* missing the deleted sequence.

                            Deletion "acatta"
                              v
       ref     ACAGTGACTGACTTGAGGGGGTGTTGACGTAGCGTAGGTCAGATCGT
       seq1    ACAGTGACTGACTTGaatta..
       seq2    ACAGTGACTGACTTGagatta..
       seq3    ACAGTGACTGACTTGacatta..
       seq4    ACAGTGACTGACTTGagatta..
       seq5    ACAGTGACTGACTTGagataa..
       seq6    ACAGTGACTGACTTGAGGGGGTGTTGACGTAGCGTAGGTCAGATCGT
       seq7    ACAGTGACTGACTTGAGGGGGTGTTGACGTAGCGTAGGTCAGATCGT
       seq1            ..aaTTAAGGGGGTGTTGACGTAGCGTAGGTCAGATCGT
       seq2           ..agaTTAAGGGGGTGTTGACGTAGCGTAGGTCAGATCGT
       seq3           ..acaTTAAGGGGGTGTTGACGTAGCGTAGGTCAGATCGT
       seq4           ..agaTTAAGGGGGTGTTGACGTAGCGTAGGTCAGATCGT
       seq5           ..agaTAAAGGGGGTGTTGACGTAGCGTAGGTCAGATCGT
                           ^^^
                      Overlap is also possible

          inst
    seq1: 1-15 Significant GAP!
    seq1: 18-N

   Duplication Scenario
   ====================

    Biological intuition:
      A duplication has occured inside a repetitive element in 
      a few copies.  Unfortunately one of these copies is picked
      as the reference causing all other copies to be become fragmented
      in the multiple alignment.

                              Duplication "AGGCATCC"
                              v       v
       ref     ACAGTGACTGACTTGAGGCATCCAGGCATCCTGGGGGTGTTGATCAGATCGT
       seq1    ACAGTGACTGACTTGAGGCATCCtgggggtgtt..
       seq2    ACAGTGACTGACTTGAGGCATCCtgggggtgtt..
       seq3    ACAGTGACTGACTTGAGGCATCCtgggggtgtt..
       seq4    ACAGTGACTGACTTGAGGCATCCtgggggtgtt..
       seq5    ACAGTGACTGACTTGAGGCATCCtgggggtgtt..
       seq6    ACAGTGACTGACTTGAGGCATCCtgggggtgtt..
       seq7    ACAGTGACTGACTTGAGGCATCCtgggggtgtt..
       seq8    ACAGTGACTGACTTGAGGCATCCAGGCATCCTGGGGGTGTTGATCAGATCGT
       seq9    ACAGTGACTGACTTGAGGCATCCAGGCATCCTGGGGGTGTTGATCAGATCGT
       seq1                   ..gacttgAGGCATCCTGGGGGTGTTGATCAGATCGT
       seq2                   ..gacttgAGGCATCCTGGGGGTGTTGATCAGATCGT
       seq3                   ..gacttgAGGCATCCTGGGGGTGTTGATCAGATCGT
       seq4                   ..gacttgAGGCATCCTGGGGGTGTTGATCAGATCGT
       seq5                   ..gacttgAGGCATCCTGGGGGTGTTGATCAGATCGT
       seq6                   ..gacttgAGGCATCCTGGGGGTGTTGATCAGATCGT
       seq7                   ..gacttgAGGCATCCTGGGGGTGTTGATCAGATCGT
       seq8                   ..gacttgAGGCATCCTGGGGGTGTTGATCAGATCGT


      seq1: 1-23  Significant Overlap!
      seq1: 16-N 


    Strategy:

      1.  Look for a set of instance sequences which match more than
          once to the reference sequence.
      2.  Find average end/start pairs for all sequences:
            - Create a histogram array over the entire consensus
            - Run a N bp window over the histogram array and mark
              end/start positions at peaks.
      3.  Consider all serial pairs of end/start pairs and determine if
          a deletion or duplication may have occured:
               - Deletion if large gap occurs between end and start pair.
                   4. Get each aligned + unaligned sequence which overlaps
                      the gap.
                   5. Compare all vs all
                   6. Pick higest scoring sequence
                   7. Insert into consensus 
               - Duplication if large overlap occurs between end and start
                 pair.
                   4. Remove consensus between positions


  Currently used by Refiner

=cut

##---------------------------------------------------------------------##
sub _getEndStartPairs
{
  my $this = shift;

  my @endStartPairs = ();

  print "_getEndStartPairs\n" if ( $DEBUG );
  my $duplicateSeqRef = $this->_getSequenceDuplicates();

  ## TESTING
  my %nameHash   = ();
  my @startHisto = ();
  my @endHisto   = ();

  for ( my $i = 0 ; $i < $this->getNumAlignedSeqs() ; $i++ )
  {
    $nameHash{ $this->getAlignedName( $i ) }++;
    $startHisto[ $this->instRefStart( $i ) ]++;
    $endHisto[ $this->instRefEnd( $i ) ]++;
  }
  my $numUniqSequences = scalar( keys( %nameHash ) );
  print "Number of uniq sequences = $numUniqSequences\n" if ( $DEBUG );
  undef %nameHash;

  print "Picking peaks using per/pos alignments -- STARTS:\n" if ( $DEBUG );
  my $startList = $this->_pickHistogramPeaks( histogram  => \@startHisto,
                                              windowSize => 11, );

  if ( $DEBUG )
  {
    print "Final calls:\n";
    foreach my $posRec ( @{$startList} )
    {
      print " pos = "
          . $posRec->{'pos'}
          . " score = "
          . $posRec->{'score'} . "\n";
    }
  }

  print "Picking peaks using per/pos alignments -- ENDS:\n" if ( $DEBUG );
  my $endList = $this->_pickHistogramPeaks( histogram  => \@endHisto,
                                            windowSize => 11, );

  if ( $DEBUG )
  {
    print "Final calls:\n";
    foreach my $posRec ( @{$endList} )
    {
      print " pos = "
          . $posRec->{'pos'}
          . " score = "
          . $posRec->{'score'} . "\n";
    }
  }

  #my $duplicateSeqRef = $this->_getSequenceDuplicates();

  # find all matching sequences from the duplicate list
  # foreach
  my @matchedSeqs = ();
  my %startNames  = ();
  my %endNames    = ();
  my %startIdxs   = ();
  my %endIdxs     = ();
  foreach my $key ( keys( %{$duplicateSeqRef} ) )
  {

    foreach my $index ( @{ $duplicateSeqRef->{$key} } )
    {

      print "Considering sequence start: "
          . $this->instRefStart( $index ) . "\n"
          if ( $DEBUG );

      # Find start
      my $startRec;
      foreach my $start ( @{$startList} )
      {
        last if ( ( $start->{'pos'} - 11 ) > $this->instRefStart( $index ) );
        if ( ( $start->{'pos'} + 11 ) >= $this->instRefStart( $index ) )
        {

          # Found a match from this index to a start
          $startRec = $start;
          $startNames{ $start->{'pos'} }->{ $this->getAlignedName( $index ) } =
              $index;
          $startIdxs{ $start->{'pos'} }->{$index}++;
        }
      }
      print "Found match to start pos " . $startRec->{'pos'} . "\n"
          if ( $DEBUG );

      # Find end
      my $endRec;
      foreach my $end ( @{$endList} )
      {
        last if ( ( $end->{'pos'} - 11 ) > $this->instRefEnd( $index ) );
        if ( ( $end->{'pos'} + 11 ) >= $this->instRefEnd( $index ) )
        {

          # Found a match from this index to a start
          $endRec = $end;
          $endNames{ $end->{'pos'} }->{ $this->getAlignedName( $index ) } =
              $index;
          $endIdxs{ $end->{'pos'} }->{$index}++;
        }
      }
      print "Found match to end pos " . $endRec->{'pos'} . "\n" if ( $DEBUG );

      #if ( defined $endRec || defined $startRec ) {
      #  push @matchedSeqs, { 'start'=>$startRec,
      #                       'end' =>$endRec,
      #                       'index' => $index };
      #}
    }
  }

  my %startEndPairs = ();
  foreach my $start ( keys( %startNames ) )
  {
    my @results = ();
    foreach my $end ( keys( %endNames ) )
    {

      # Find shared indexes
      my @this_not_that = ();
      foreach ( keys %{ $startIdxs{$start} } )
      {
        push( @this_not_that, $_ ) if ( exists $endIdxs{$end}->{$_} );
      }
      print " This not that = " . scalar( @this_not_that ) . "\n" if ( $DEBUG );
      next if ( @this_not_that );

      # Find common keys
      my @common = ();
      foreach ( keys %{ $startNames{$start} } )
      {
        push( @common, $_ ) if ( exists $endNames{$end}->{$_} );
      }
      if ( @common > 1 )
      {
        push @results,
            {
              'endPos' => $end,
              'dist'   => abs( $start - $end ),
              'shared' => scalar( @common )
            };
      }
    }
    my @sortedResults = sort { $a->{'dist'} <=> $b->{'dist'} } @results;
    my $result        = $sortedResults[ 0 ];
    if ( !defined $startEndPairs{ $result->{'endPos'} }
        || $startEndPairs{ $result->{'endPos'} }->{'dist'} > $result->{'dist'} )
    {
      $startEndPairs{ $result->{'endPos'} } = {
                                                'start'  => $start,
                                                'dist'   => $result->{'dist'},
                                                'shared' => $result->{'shared'}
      };
    }
    if ( $DEBUG )
    {
      print "Start: $start\n";
      foreach my $result ( @sortedResults )
      {
        print "   EndMatch: "
            . $result->{'endPos'}
            . " dist: "
            . $result->{'dist'}
            . " shared: "
            . $result->{'shared'} . "\n";
      }
    }

  }

  print "----------Final calls---------------\n" if ( $DEBUG );
  foreach my $endPos ( keys( %startEndPairs ) )
  {
    my $startPos = $startEndPairs{$endPos}->{'start'};
    print "EndPos = $endPos  StartPos = $startPos " if ( $DEBUG );
    my $avgGap      = 0;
    my $avgGapCount = 0;
    foreach my $startName ( keys %{ $startNames{$startPos} } )
    {
      if ( exists $endNames{$endPos}->{$startName} )
      {
        my $startIdx = $startNames{$startPos}->{$startName};
        my $endIdx   = $endNames{$endPos}->{$startName};

        #my $lftSeq   = $this->seq( $endIdx );
        my $lftSeq = $this->getAlignedSeq( $endIdx );
        $lftSeq =~ s/-//g;
        $avgGap += $this->getAlignedSeqStart( $startIdx ) -
            ( $this->getAlignedSeqStart( $endIdx ) + length( $lftSeq ) );
        $avgGapCount++;
      }
    }
    if ( $avgGapCount > 0 )
    {
      $avgGap /= $avgGapCount;
    }
    print "avgGap = $avgGap avgGapCount = $avgGapCount\n" if ( $DEBUG );
    push @endStartPairs,
        {
          'refEnd'      => $endPos,
          'refStart'    => $startPos,
          'avgGapWidth' => $avgGap
        };
  }

  #my @sortedMatchedSeqs = sort
  #             { $a->{'start'}->{'pos'} <=> $b->{'start'}->{'pos'}
  #                                  ||
  #               $a->{'end'}->{'pos'} <=> $b->{'end'}->{'pos'}  }
  #                        @matchedSeqs;
  #
  #    my $prevStart = -1;
  #    my $prevEnd = -1;
  #    my $count = -1;
  #    print "Matched endpoints:\n";
  #    foreach my $seq ( @sortedMatchedSeqs ) {
  #      if ( $seq->{'start'}->{'pos'} != $prevStart ||
  #           $seq->{'end'}->{'pos'} != $prevEnd ) {
  #        print " count = $count\n" if ( $count > -1 );
  #        print " start = " . $seq->{'start'}->{'pos'}  .
  #              " end = " . $seq->{'end'}->{'pos'} . "";
  #        $prevEnd = $seq->{'end'}->{'pos'};
  #        $prevStart = $seq->{'start'}->{'pos'};
  #        $count = 1;
  #      }else {
  #        $count++;
  #      }
  #    }
  #    print " count = $count\n" if ( $count > -1 );

  #print "Peak calls:\n";
  #foreach my $peak ( @{ $peakList } ) {
  #  print " pos = ". $peak->{'pos'} . " score = " . $peak->{'score'} . "\n";
  #  push @endStartPairs, { 'refEnd' => $peak->{'pos'} - 1,
  #                         'refStart' => $peak->{'pos'} + 1,
  #                         'avgGapWidth' => 0 };
  #}

  ## END TESTING
  if ( 0 )
  {

    ## Cluster APPROACH
    my @clusters = ();
    foreach my $name ( keys( %{$duplicateSeqRef} ) )
    {
      foreach my $index ( @{ $duplicateSeqRef->{$name} } )
      {
        my $i;
        my $consStart = $this->instRefStart( $index );
        my $consEnd   = $this->instRefEnd( $index );
        for ( $i = 0 ; $i <= $#clusters ; $i++ )
        {
          my $cluster = $clusters[ $i ];
          next
              if (    $cluster->{'start'} > $consEnd
                   || $cluster->{'end'} < $consStart );
          my $left = $consStart;
          $left = $cluster->{'start'} if ( $cluster->{'start'} > $left );
          my $right = $consEnd;
          $right = $cluster->{'end'} if ( $cluster->{'end'} < $right );
          my $overlap = $right - $left + 1;
          last
              if ( ( $overlap / ( $consEnd - $consStart + 1 ) ) > 0.8
             || ( $overlap / ( $cluster->{'end'} - $cluster->{'start'} + 1 ) ) >
             0.8 );
        }
        if ( $i <= $#clusters )
        {

          # Add to existing cluster
          my $left = $consStart;
          $left = $clusters[ $i ]->{'start'}
              if ( $clusters[ $i ]->{'start'} < $left );
          my $right = $consEnd;
          $right = $clusters[ $i ]->{'end'}
              if ( $clusters[ $i ]->{'end'} > $right );
          $clusters[ $i ]->{'start'} = $left;
          $clusters[ $i ]->{'end'}   = $right;
          push @{ $clusters[ $i ]->{'indices'} }, $index;
          print "   -- consstart = $consStart consend = $consEnd\n";
          $clusters[ $i ]->{'leftHisto'}->[ $consStart ]++;
          $clusters[ $i ]->{'rightHisto'}->[ $consEnd ]++;
        } else
        {

          # Make a new cluster
          my @lHistogram = ();
          my @rHistogram = ();
          $lHistogram[ $consStart ]++;
          $rHistogram[ $consEnd ]++;
          push @clusters,
              {
                'start'      => $consStart,
                'end'        => $consEnd,
                'leftHisto'  => \@lHistogram,
                'rightHisto' => \@rHistogram,
                'indices'    => [ $index ]
              };
        }
      }
    }
    print "Initial Clusters: " . ( $#clusters + 1 ) . "\n";

    # Remove small clusters and clusters where coverage is not
    # significant
    for ( my $i = $#clusters ; $i >= 0 ; $i-- )
    {
      if ( $#{ $clusters[ $i ]->{'indices'} } < 1 )
      {
        print "Removing a small cluster\n";
        splice( @clusters, $i, 1 );
        next;
      }
      my $clusterOverlapSeqs = 0;
      for ( my $j = 0 ; $j < $this->getNumAlignedSeqs() ; $j++ )
      {
        my $instStart = $this->instRefStart( $j );
        my $instEnd   = $this->instRefEnd( $j );
        next
            if (    $instStart > $clusters[ $i ]->{'end'}
                 || $instEnd < $clusters[ $i ]->{'start'} );
        my $left = $instStart;
        $left = $clusters[ $i ]->{'start'}
            if ( $clusters[ $i ]->{'start'} > $left );
        my $right = $instEnd;
        $right = $clusters[ $i ]->{'end'}
            if ( $clusters[ $i ]->{'end'} < $right );
        my $overlap = $right - $left + 1;
        next
            if ( $overlap <
          ( ( $clusters[ $i ]->{'end'} - $clusters[ $i ]->{'start'} ) * 0.6 ) );
        $clusterOverlapSeqs++;
      }
      if (
        ( $#{ $clusters[ $i ]->{'indices'} } + 1 ) / $clusterOverlapSeqs < 0.7 )
      {
        print "Removing a cluster because it is not representative. "
            . " clusterOverlapSeqs = $clusterOverlapSeqs and clusteSize = "
            . ( $#{ $clusters[ $i ]->{'indices'} } + 1 ) . "\n";
        splice( @clusters, $i, 1 );
        next;
      }
    }
    print "Clusters Left: " . ( $#clusters + 1 ) . "\n";
    for ( my $i = 0 ; $i <= $#clusters ; $i++ )
    {
      print "Cluster #$i: " . ( $#{ $clusters[ $i ]->{'indices'} } + 1 ) . "\n";
      print "  "
          . $clusters[ $i ]->{'start'} . "-"
          . $clusters[ $i ]->{'end'} . "\n";
    }

    # Print out our accomplishments
    for ( my $i = 1 ; $i <= $#clusters ; $i++ )
    {
      my $refStartScore = 0;
      my $refEndScore   = 0;
      my $refStart      = -1;
      my $refEnd        = -1;
      my $instStart     = -1;
      my $instEnd       = -1;
      print "         | \n";
      print "         |  \n";
      print " Calling Right Cluster Edge:\n";
      ( $refStartScore, $refStart ) = _pickHistogramPeak(
                                    histogram => $clusters[ $i ]->{'leftHisto'},
                                    windowSize         => 11,
                                    useHighestInWindow => 1
      );
      print " Calling Left Cluster Edge:\n";
      ( $refEndScore, $refEnd ) = _pickHistogramPeak(
                               histogram => $clusters[ $i - 1 ]->{'rightHisto'},
                               windowSize         => 11,
                               useHighestInWindow => 1
      );

      # Determine the average gap width for sequences crossing clusters
      my $negGapCount = ();
      my @gapHisto    = ();
      my $gapCount    = 0;
      foreach my $index1 ( @{ $clusters[ $i - 1 ]->{'indices'} } )
      {
        my $name1 = $this->getAlignedName( $index1 );
        foreach my $index2 ( @{ $clusters[ $i ]->{'indices'} } )
        {
          my $name2 = $this->getAlignedName( $index2 );
          next if ( $name1 ne $name2 );

          #my $lftSeq = $this->seq( $index1 );
          my $lftSeq = $this->getAlignedSeq( $index1 );
          $lftSeq =~ s/-//g;
          print "adding "
              . ( $this->getAlignedSeqStart( $index2 ) -
                  ( $this->getAlignedSeqStart( $index1 ) + length( $lftSeq ) ) )
              . " to average\n";
          my $gap = $this->getAlignedSeqStart( $index2 ) -
              ( $this->getAlignedSeqStart( $index1 ) + length( $lftSeq ) );
          if ( $gap >= 0 )
          {
            $gapHisto[ $gap ]++;
          } else
          {
            $negGapCount++;
            $gapHisto[ abs( $gap ) ]++;
          }
          $gapCount++;
          last;
        }
      }
      my ( $gapScore, $avgGap ) = _pickHistogramPeak(
                                                      histogram  => \@gapHisto,
                                                      windowSize => 5,
                                                      useHighestInWindow => 1
      );

      if ( $negGapCount / $gapCount > 0.5 )
      {
        $avgGap = -$avgGap;
      }

      print "Ref:   ----Cluster#"
          . ( $i - 1 )
          . "--+ $refEnd    $refStart +---Cluster#"
          . "$i-----\n";
      my $gapDist = $refStart - $refEnd;

      print "           Gap distance (ref)= $gapDist\n";
      print "           Avg Gap distance (Inst)= $avgGap\n";
      print
"           refStartScore = $refStartScore refEndScore=$refEndScore\n";
      my $refStartPct =
          ( $refStartScore / ( $#{ $clusters[ $i ]->{'indices'} } + 1 ) );
      my $refEndPct =
          ( $refEndScore / ( $#{ $clusters[ $i - 1 ]->{'indices'} } + 1 ) );
      print "           refStartPct = $refStartPct refEndPct=$refEndPct\n";

      if ( $refEndPct > .5 && $refStartPct > .5 )
      {
        print "         **** ...Saved!\n";
        push @endStartPairs,
            {
              'refEnd'      => $refEnd,
              'refStart'    => $refStart,
              'avgGapWidth' => $avgGap
            };
      } else
      {
        print "         **** ...Deleted!\n";
      }

      print "         |   \n";
      print "         |   \n";

      #print "  #:     " . ( $#{ $clusters[$i]->{'indices'} } + 1 ) . "\n";
    }
  }    # if ( 0 )

  return ( \@endStartPairs );

}

##
##  HTML:
##    Some work here:
##          http://jsfiddle.net/Ujw5b/14
##      and http://jsfiddle.net/4XeX4/28
##
##

##---------------------------------------------------------------------##

=head2 toSTK()

  Use: $obj->toSTK( filename => "filename",
                    includeReference => 1, header => "## foo", 
                    id => "fullID" );

  Export the multiple alignment data to a file in the Stockholm 1.0
  format.

=cut

##---------------------------------------------------------------------##
sub toSTK
{
  my $object     = shift;
  my %parameters = @_;

  my $id = $object->getReferenceName();
  $id = $parameters{'id'} if ( defined $parameters{'id'} );

  my $OUT;
  if ( $parameters{'filename'} )
  {
    open $OUT, ">$parameters{'filename'}"
        or die $CLASS
        . "::toSTK: Unable to open "
        . "results file: $parameters{'filename'} for writing : $!";
  } else
  {
    $OUT = *STDOUT;
  }

  # Print header
  print $OUT "# STOCKHOLM 1.0\n";
  print $OUT "#=GF ID $id\n";
  print $OUT "#=DE refLength="
      . $object->getGappedReferenceLength()
      . " refName="
      . $object->getReferenceName() . "\n";
  print $OUT "#=BM RepeatMasker/MultAln\n";

  my $numSeqs = $object->getNumAlignedSeqs();
  $numSeqs += 1 if ( defined $parameters{'includeReference'} );
  print $OUT "#=SQ $numSeqs\n";

  if ( $parameters{'header'} )
  {
    print $OUT "$parameters{'header'}";
  }

  # Determine max id length
  my $maxNameLen = 0;
  if ( defined $parameters{'includeReference'} )
  {
    $maxNameLen = length( $object->getReferenceName() )
        if ( length( $object->getReferenceName() ) > $maxNameLen );
  }
  for ( my $i = 0 ; $i < $object->getNumAlignedSeqs() ; $i++ )
  {
    $maxNameLen = length( $object->getAlignedName( $i ) )
        if ( length( $object->getAlignedName( $i ) ) > $maxNameLen );
  }

  # Spec indicates id shouldn't be longer than 255
  if ( $maxNameLen > 255 )
  {
    warn $CLASS
        . "::toSTK(): Truncating id's because at least one is longer "
        . "than allowed length ( 255 ).\n";
    $maxNameLen = 255;
  }

  # Print out the reference using the #=GC RF line
  my $seq = $object->getReferenceSeq();
  $seq =~ s/-/./g;
  $seq =~ s/[ACGTBDHVRYKMSWN]/x/ig;
  my $name = "#=GC RF ";
  if ( length( $name ) <= $maxNameLen )
  {
    $name = $name . " " x ( $maxNameLen - length( $name ) );
  } else
  {
    $name = substr( $name, 0, $maxNameLen );
  }
  print $OUT "$name  $seq\n";

  if ( defined $parameters{'includeReference'} )
  {
    $seq = $object->getReferenceSeq();
    $seq =~ s/-/./g;
    $name = "ref:" . $object->getReferenceName();
    if ( length( $name ) <= $maxNameLen )
    {
      $name = $name . " " x ( $maxNameLen - length( $name ) );
    } else
    {
      $name = substr( $name, 0, $maxNameLen );
    }
    print $OUT "$name  $seq\n";
  }

  # Now print out the aligned sequences
  my $maxSeqLen = $object->getGappedReferenceLength();
  for ( my $i = 0 ; $i < $object->getNumAlignedSeqs() ; $i++ )
  {
    my $start = $object->getAlignedStart( $i );
    my $end   = $object->getAlignedEnd( $i );
    my $seq   = '';
    if ( $start > 0 )
    {
      $seq = '.' x ( $start );
    }
    $seq .= $object->getAlignedSeq( $i );
    $seq =~ s/-/./g;

    if ( length( $seq ) < $maxSeqLen )
    {
      $seq .= '.' x ( $maxSeqLen - length( $seq ) );
    }

    my $name = $object->getAlignedName( $i );

    if ( length( $name ) <= $maxNameLen )
    {
      $name = $name . " " x ( $maxNameLen - length( $name ) );
    } else
    {
      $name = substr( $name, 0, $maxNameLen );
    }

    print $OUT "$name  $seq\n";
  }
  print $OUT "//\n";
  if ( $parameters{'filename'} )
  {
    close $OUT;
  }
}

##---------------------------------------------------------------------##

=head2 toMSF()

  Use: $obj->toMSF( filename => "filename",
                    includeReference => 1 );

  Export the multiple alignment data to a file in the MSF format.

=cut

##---------------------------------------------------------------------##
sub toMSF
{
  my $object     = shift;
  my %parameters = @_;

  my $OUT;
  if ( $parameters{'filename'} )
  {
    open $OUT, ">$parameters{'filename'}";
  } else
  {
    $OUT = *STDOUT;
  }

  my $maxNameLen = 0;

  # Print header
  print $OUT " multaln.msf  MSF: "
      . $object->getGappedReferenceLength()
      . "   Type: N  "
      . localtime( time )
      . " Check: 0 ..\n\n";
  if ( defined $parameters{'includeReference'} )
  {
    print $OUT " Name: "
        . $object->getReferenceName()
        . "    Len: "
        . $object->getGappedReferenceLength()
        . "    Check: 0    Weight: 1.00\n";
    $maxNameLen = length( $object->getReferenceName() )
        if ( length( $object->getReferenceName() ) > $maxNameLen );
  }
  for ( my $i = 0 ; $i < $object->getNumAlignedSeqs() ; $i++ )
  {
    print $OUT " Name: "
        . $object->getAlignedName( $i )
        . "    Len: "
        . ( $object->getAlignedEnd( $i ) - $object->getAlignedStart( $i ) )
        . "    Check: 0    Weight: 1.00\n";
    $maxNameLen = length( $object->getAlignedName( $i ) )
        if ( length( $object->getAlignedName( $i ) ) > $maxNameLen );
  }
  print $OUT "\n//\n";

  my $name      = "";
  my $start     = "";
  my $end       = "";
  my $seq       = "";
  my $lineStart = 0;
  my $lineEnd   = 49;
  while ( $lineStart < $object->getGappedReferenceLength() )
  {

    # Print out the reference first
    if ( defined $parameters{'includeReference'} )
    {
      $seq = substr( $object->getReferenceSeq(),
                     $lineStart, $lineEnd - $lineStart + 1 );
      $name = "ref:" . $object->getReferenceName();
      if ( length( $name ) > 16 )
      {
        $name = substr( $name, 0, 16 );
      }
      if ( $lineStart == 0 )
      {
        $start = $object->getReferenceSeqStart();
      } else
      {
        my $priorSeq = substr( $object->getReferenceSeq(), 0, $lineStart );
        my $numLetters = ( $priorSeq =~ tr/A-Za-z/A-Za-z/ );
        $start = $numLetters;
      }
      my $numLetters = ( $seq =~ tr/A-Za-z/A-Za-z/ );
      $end = $start + $numLetters - 1;

      if ( length( $name ) <= $maxNameLen )
      {
        $name = $name . " " x ( $maxNameLen - length( $name ) );
      } else
      {
        $name = substr( $name, 0, $maxNameLen );
      }

      $seq =~ s/(.{10})/$1 /g;

      print $OUT "$name  $seq\n";

    }

    # Now print out the aligned sequences
    for ( my $i = 0 ; $i < $object->getNumAlignedSeqs() ; $i++ )
    {
      $start = $object->getAlignedStart( $i );
      $end   = $object->getAlignedEnd( $i );
      next if ( $start >= $lineEnd );
      next if ( $end <= $lineStart );
      $seq = '';
      if ( $start > $lineStart )
      {
        $seq = '-' x ( $start - $lineStart );
      }
      my $seqStart = $lineStart - $start;
      $seqStart = 0 if ( $seqStart < 0 );
      my $seqEnd = $lineEnd - $start;
      $seqEnd = $end if ( $seqEnd > $end );
      $seq .= substr( $object->getAlignedSeq( $i ),
                      $seqStart, $seqEnd - $seqStart + 1 );
      $name = $object->getAlignedName( $i );
      my $numLetters;

      if ( $seqStart == 0 )
      {
        $start = $object->getAlignedSeqStart( $i );
      } else
      {
        my $priorSeq = substr( $object->getAlignedSeq( $i ), 0, $seqStart );
        $numLetters = ( $priorSeq =~ tr/A-Z/A-Z/ );
        $start = $object->getAlignedSeqStart( $i ) + $numLetters;
      }
      $numLetters = ( $seq =~ tr/A-Z/A-Z/ );
      $end        = $start + $numLetters - 1;

      if ( length( $name ) <= $maxNameLen )
      {
        $name = $name . " " x ( $maxNameLen - length( $name ) );
      } else
      {
        $name = substr( $name, 0, $maxNameLen );
      }

      $seq =~ s/(.{10})/$1 /g;

      print $OUT "$name  $seq\n";

    }
    print $OUT "\n";
    $lineStart = $lineEnd + 1;
    $lineEnd   = $lineStart + 49;
  }
  if ( $parameters{'filename'} )
  {
    close $OUT;
  }
}

##---------------------------------------------------------------------##

=head2 printAlignments()

  Use: $obj->printAlignments();

  Print the multiple alignment data to the screen breaking it up
  into 50 bp chunks.

=cut

##---------------------------------------------------------------------##
sub printAlignments
{
  my $object     = shift;
  my %parameters = @_;

  my $blockSize = 50;
  if ( $parameters{'blockSize'} )
  {
    $blockSize = $parameters{'blockSize'};
  }

  my $inclRef = 0;
  $inclRef = 1 if ( $parameters{'inclRef'} );

  my $showScore = 0;
  $showScore = 1 if ( $parameters{'showScore'} );

  my $consensus = "";
  if ( $parameters{'showCons'} )
  {
    $consensus = $object->consensus( inclRef => $inclRef );
  }

  my @sortedIndexes = ( 0 .. ( $object->getNumAlignedSeqs() - 1 ) );
  if ( !$parameters{'origOrder'} )
  {
    @sortedIndexes = sort {
      $object->getAlignedStart( $a ) <=> $object->getAlignedStart( $b )
    } ( 0 .. ( $object->getNumAlignedSeqs() - 1 ) );
  }

  my $maxIDLen = length( $object->getReferenceName() );
  foreach my $i ( @sortedIndexes )
  {
    my $tLen = length( $object->getAlignedName( $i ) );
    $maxIDLen = $tLen if ( $tLen > $maxIDLen );
  }

  # Generate the scores if requested
  my $columns;
  my $scoreArray;
  my $maxScoreLen = 0;
  if ( $showScore )
  {

    # Use default matrix
    ( $columns, $scoreArray ) = $object->getLowScoringAlignmentColumns();

    # Find the largest score
    for ( my $j = 0 ; $j <= $#{$scoreArray} ; $j++ )
    {
      my $num = sprintf( "%0.1f", $scoreArray->[ $j ] );
      $maxScoreLen = length( $num ) if ( $maxScoreLen < length( $num ) );
      $scoreArray->[ $j ] = $num;
    }

  }

  # absolute positions in the reference string ( not base position )
  my $lineStart        = 0;
  my $lineEnd          = $blockSize - 1;
  my $refBaseStartPos  = $object->getReferenceSeqStart();
  my $consBaseStartPos = 1;
  while ( $lineStart < $object->getGappedReferenceLength() )
  {

    # Show the score if requested
    if ( $showScore )
    {
      for ( my $rows = 0 ; $rows < $maxScoreLen ; $rows++ )
      {
        print " " x ( $maxIDLen + 6 + 2 );
        for ( my $cols = 0 ; $cols < $blockSize ; $cols++ )
        {
          my $thisDigits =
              " " x
              ( $maxScoreLen - length( $scoreArray->[ $cols + $lineStart ] ) )
              . $scoreArray->[ $cols + $lineStart ];
          print "" . substr( $thisDigits, $rows, 1 );
        }
        print "\n";
      }
    }

    # Print out the consensus if requested
    if ( $consensus ne "" )
    {
      my $seq        = substr( $consensus, $lineStart, $blockSize );
      my $name       = "consensus";
      my $numLetters = ( $seq =~ tr/A-Za-z/A-Za-z/ );
      my $end        = $consBaseStartPos + $numLetters - 1;
      my $outStr     = $name
          . " " x ( $maxIDLen - length( $name ) ) . " "
          . " " x ( 6 - length( $consBaseStartPos ) )
          . $consBaseStartPos . " "
          . $seq
          . " " x ( $blockSize - length( $seq ) ) . "    "
          . $end . "\n";
      print "$outStr";
      $consBaseStartPos = $end + 1;
    }

    # Print out the reference
    my $seq = substr( $object->getReferenceSeq(), $lineStart, $blockSize );
    my $name = substr( "ref:" . $object->getReferenceName(), 0, $maxIDLen );

    my $numLetters = ( $seq =~ tr/A-Za-z/A-Za-z/ );
    my $end        = $refBaseStartPos + $numLetters - 1;
    my $outStr     = $name
        . " " x ( $maxIDLen - length( $name ) ) . " "
        . " " x ( 6 - length( $refBaseStartPos ) )
        . $refBaseStartPos . " "
        . $seq
        . " " x ( $blockSize - length( $seq ) ) . "    "
        . $end . "\n";
    print "$outStr";

    $refBaseStartPos = $end + 1;

    # Now print out the aligned sequences
    foreach my $i ( @sortedIndexes )
    {
      my $start = $object->getAlignedStart( $i );
      my $end   = $object->getAlignedEnd( $i );
      next if ( $start >= $lineEnd );
      next if ( $end <= $lineStart );
      $seq = '';
      if ( $start > $lineStart )
      {
        $seq = ' ' x ( $start - $lineStart );
      }
      my $seqStart = $lineStart - $start;
      $seqStart = 0 if ( $seqStart < 0 );
      my $seqEnd = $lineEnd - $start;
      $seqEnd = $end if ( $seqEnd > $end );
      $seq .= substr( $object->getAlignedSeq( $i ),
                      $seqStart, $seqEnd - $seqStart + 1 );
      $name = $object->getAlignedName( $i );

      #if ( length( $name ) > 16 )
      #{
      #  $name = substr( $name, 0, 16 );
      #}
      if ( $seqStart == 0 )
      {
        $start = $object->getAlignedSeqStart( $i );
      } else
      {
        my $priorSeq = substr( $object->getAlignedSeq( $i ), 0, $seqStart );
        $numLetters = ( $priorSeq =~ tr/A-Z/A-Z/ );
        $start = $object->getAlignedSeqStart( $i ) + $numLetters;
      }
      $numLetters = ( $seq =~ tr/A-Z/A-Z/ );
      $end        = $start + $numLetters - 1;

      my $outStr = $name
          . " " x ( $maxIDLen - length( $name ) ) . " "
          . " " x ( 6 - length( $start ) )
          . $start . " "
          . $seq
          . " " x ( $blockSize - length( $seq ) ) . "    "
          . $end . "\n";
      print "$outStr";

    }
    print "\n";
    $lineStart = $lineEnd + 1;
    $lineEnd   = $lineStart + $blockSize - 1;
  }
}

##---------------------------------------------------------------------##
## Use: my ($freqData, $analysisCons) = substFrequencey();
##
##  Returns
##
##     This is the heart of our substitution analysis project.
##     It takes the multAln data and calculates substitution
##     frequencies for mono/tri nucleotides.  Substitutions
##     are counted by sliding a three base pair window over
##     the consensus and instance sequences.  Positions are
##     counted if:
##
##             o They are not flanked by an insertion or deletion
##               Mono-nucleotides are also counted inside
##               a tri-nucleotide window so a site will be
##               disqualified if the indel is within 2bp of
##               the site.  Ie.  - ACT G  The C would not
##               be considered.
##
##
##---------------------------------------------------------------------##
sub substFrequency
{
  my $object = shift;

  #
  #  During substitution tallying a base is considered if:
  #
  #    o It is not flanked by an indel
  #
  my $conSubstBase  = "";
  my $consLeftBase  = "";
  my $consRightBase = "";
  my $substBase     = "";
  my $leftBase      = "";
  my $rightBase     = "";
  my $seqIndex      = 0;
  my $baseIndex     = 0;
  my $leftSeqToBase;
  my $rightSeqToBase;
  my $rightBasePos = 0;
  my $leftBasePos  = 0;

  # Initializations
  my $freqData     = SequenceSimilarityMatrix->new();   # Result datastructure
  my $analysisCons = lc( $object->getReferenceSeq() );  # Consensus string which
       #  indicates the positions
       #  considered for sub analsys
       #  as uppercase bases.
  my $consPos = 0;    # Absolute position within
                      #  the consensus

  # go from A<here>CC---GCTT-AA<tohere>G"
  foreach $baseIndex ( 1 .. length( $analysisCons ) - 2 )
  {

    # Get a consensus base to consider it's substitutions
    $conSubstBase = substr( $object->{'alignCol'}[ 0 ]{seq}, $baseIndex, 1 );

    # Do not need to consider deletions
    next if ( $conSubstBase eq "-" );
    $consPos++;

    # Next find the left flanking base
    $leftBasePos = $baseIndex - 1;
    while (
            (
              $consLeftBase =
              substr( $object->{'alignCol'}[ 0 ]{seq}, $leftBasePos, 1 )
            ) eq "-"
            && $leftBasePos > -1
        )
    {
      $leftBasePos--;
    }

    # There appears to be no left flanking base (edge effect)
    next if ( $leftBasePos < 0 );

    # Next find the right flanking base
    $rightBasePos = $baseIndex + 1;
    while (
            (
              $consRightBase =
              substr( $object->{'alignCol'}[ 0 ]{seq}, $rightBasePos, 1 )
            ) eq "-"
            && $rightBasePos < length( $object->getReferenceSeq() )
        )
    {
      $rightBasePos++;
    }

    # There appears to be no right flanking base (edge effect)
    next if ( $rightBasePos >= length( $object->getReferenceSeq() ) );

    #
    # Now lets consider these three positions in all of the hits
    #
    foreach $seqIndex ( 0 .. $object->getNumAlignedSeqs() - 1 )
    {

      # Do not consider hits which do not contain these three bases.
      next
          if (    $leftBasePos < $object->getAlignedStart( $seqIndex )
               || $rightBasePos >
               length( $object->getAlignedSeq( $seqIndex ) ) +
               $object->getAlignedStart( $seqIndex ) - 1 );

      # Lets grab the corresponding bases from the hit
      $substBase = substr( $object->getAlignedSeq( $seqIndex ),
                           $baseIndex - $object->getAlignedStart( $seqIndex ),
                           1 );

      # No need to consider hits in which this base is deleted or masked
      next if ( $substBase eq "-" || $substBase eq "*" );

      # Total bases aligned
      $freqData->{totBasesAligned}++;
      $freqData->{totBasesAlignedPos}[ $consPos ]++;

      # Look for left/right deletion characters
      $leftBase = substr( $object->getAlignedSeq( $seqIndex ),
                          $leftBasePos - $object->getAlignedStart( $seqIndex ),
                          1 );
      $rightBase = substr( $object->getAlignedSeq( $seqIndex ),
                          $rightBasePos - $object->getAlignedStart( $seqIndex ),
                          1 );

      # Now lets grab the insertion characters
      $leftSeqToBase = substr(
                   $object->getAlignedSeq( $seqIndex ),
                   ( $leftBasePos + 1 ) - $object->getAlignedStart( $seqIndex ),
                   $baseIndex - $leftBasePos - 1
      );
      $rightSeqToBase = substr(
                     $object->getAlignedSeq( $seqIndex ),
                     ( $baseIndex + 1 ) - $object->getAlignedStart( $seqIndex ),
                     $rightBasePos - $baseIndex - 1
      );

      # Check for leftside insertion
      if ( $leftBasePos < $baseIndex
           && ( $leftSeqToBase =~ tr/-/-/ ) != length( $leftSeqToBase ) )
      {
        next;

        # Check for rightside insertion
      } elsif ( $rightBasePos > $baseIndex
                && ( $rightSeqToBase =~ tr/-/-/ ) != length( $rightSeqToBase ) )
      {
        next;

        # Check for rightside deletion
      } elsif ( $rightBase eq "-" || $rightBase eq "*" )
      {
        next;

        # Check for leftside deletion
      } elsif ( $leftBase eq "-" || $leftBase eq "*" )
      {
        next;
      }

      # Uppercase base in analysis consensus to indicate
      # we are considering it.
      substr( $analysisCons, $baseIndex, 1 ) = $conSubstBase;

      #
      # Record our results
      #
      $freqData->{monoAlphabetHash}{$conSubstBase}             = 1;
      $freqData->{monoAlphabetHash}{ _compl( $conSubstBase ) } = 1;
      $freqData->{monoAlphabetHash}{$substBase}                = 1;
      $freqData->{monoAlphabetHash}{ _compl( $substBase ) }    = 1;
      $freqData->{trippleAlphabetHash}
          { $consLeftBase . $conSubstBase . $consRightBase } = 1;
      $freqData->{trippleAlphabetHash}
          { _compl( $consLeftBase . $conSubstBase . $consRightBase ) } = 1;
      $freqData->{trippleAlphabetHash}{ $leftBase . $substBase . $rightBase } =
          1;
      $freqData->{trippleAlphabetHash}
          { _compl( $leftBase . $substBase . $rightBase ) } = 1;

      # TODO: Document this change
      $freqData->{monoSubSingleCounts}{ $conSubstBase . $substBase }++;
      $freqData->{monoSubCounts}{ $conSubstBase . $substBase }++;
      $freqData->{monoSubCounts}
          { _compl( $conSubstBase ) . _compl( $substBase ) }++;

      my $triFwdKey =
            $consLeftBase
          . $conSubstBase
          . $consRightBase
          . $leftBase
          . $substBase
          . $rightBase;
      my $triBkwKey =
            _compl( $consLeftBase . $conSubstBase . $consRightBase )
          . _compl( $leftBase . $substBase . $rightBase );

      # General tri-nucleotide counts
      # TODO: Document this additional matrix datamember
      $freqData->{trippleSubSingleCounts}{$triFwdKey}++;
      $freqData->{trippleSubCounts}{$triFwdKey}++;
      $freqData->{trippleSubCounts}{$triBkwKey}++;

      $triFwdKey = $consLeftBase . $conSubstBase . $consRightBase;
      $triBkwKey = _compl( $consLeftBase . $conSubstBase . $consRightBase );
      _compl( $substBase );

      # Position specific tri-nucleotide counts
      $freqData->{triSubPosCounts}{$triFwdKey}{$leftBasePos}{$substBase}++;
      $freqData->{triSubPosCounts}{$triBkwKey}{$leftBasePos}
          { _compl( $substBase ) }++;
      $freqData->{totalAnalyzedBases}++;
      $freqData->{totBasesAnalyzedPos}[ $consPos ]++;
    }
  }
  return ( $freqData, $analysisCons );
}

##---------------------------------------------------------------------##
## Use:  my $cSeq = _compl($seq);
##
##          $seq       :  The DNA sequence to be complemented
##  Returns
##
##     The genetic reverse complement of the DNA sequence.
##
##---------------------------------------------------------------------##
sub _compl
{
  my $seq = shift;
  $seq =~ tr/ACGTRYKMSWBDHV/TGCAYRMKWSVHDB/;
  return ( reverse( $seq ) );
}

##---------------------------------------------------------------------##
## Use:
##
##
##  Returns
##
##
##---------------------------------------------------------------------##
sub consensusWOInsertions
{
  my $object     = shift;
  my $matrixFile = shift;
  my $origCons   = my $newCons = $object->consensus( $matrixFile );
  my $i          = 0;
  my $reference  = $object->getReferenceSeq();
  for ( $i = 0 ; $i < length( $newCons ) ; $i++ )
  {
    substr( $newCons, $i, 1 ) = "-" if ( substr( $reference, $i, 1 ) eq "-" );
  }
  return ( $origCons, $newCons );
}

##---------------------------------------------------------------------##
## Use:
##
##
##  Returns
##
##
##---------------------------------------------------------------------##
sub buildConsensusFromArrayNearlyOrig
{
  my %parameters = @_;

  croak $CLASS. "::buildConsensus: Missing matrix parameter!\n"
      if ( !defined $parameters{'matrix'} );
  my $myMatrix = $parameters{'matrix'};

  my $alphabet_r = $myMatrix->{'alphabetArray'};
  my $matrix_r   = $myMatrix->{'matrixHash'};
  my $n          = "";

  #
  # This is what boosts the value of the CG
  # consensus comparison if the instance dinucs
  # are CA or TG.
  #
  # TODO: Generalize this and the gap penalties!
  my $CGparam = 12;    # TG or CA match is 19, TG <-> CA mismatch -12
                       # Previously set at 14. Seems to overestimate in very
                       #   old elements.
  my $TAparam = -5;    # TG or CA to TA is -4, so slightly worse than that
                       #   CG -> TA mismatch would have been -8

  foreach $n ( @$alphabet_r )
  {
    $matrix_r->{ $n, '-' } = $matrix_r->{ '-', $n } = -6;
  }

  push @$alphabet_r, '-';
  $matrix_r->{ '-', '-' } = 3;

  # TODO: Make sure it exists
  my $sequences = $parameters{'sequences'};
  my @profile   = ();
  foreach my $seq ( @{$sequences} )
  {
    my $i = 0;
    grep $profile[ $i++ ]{$_}++, split( '', $seq );
  }

  my $consensus = '';
  my @cScore    = ();
  my $i         = 0;
  foreach $i ( 0 .. $#profile )
  {
    my $maxScore = -1000000;
    my $n        = '';

    # Currently the "*" mask character is ignored.
    foreach $a ( @$alphabet_r )
    {
      my $score = 0;
      foreach $b ( keys %{ $profile[ $i ] } )
      {
        next if ( $b eq " " );
        $score += $profile[ $i ]{$b} * $matrix_r->{ $a, $b };
      }
      if ( $score > $maxScore )
      {
        $n        = $a;
        $maxScore = $score;
      }
    }
    $consensus .= $n;
    push @cScore, $maxScore;
  }

  #
  #   go through the consensus and consider changing each dinucleotide
  #   to a 'CG'
  #
FLOOP: foreach $i ( 0 .. length( $consensus ) - 2 )
  {
    next if ( substr( $consensus, $i, 1 ) eq '-' );
    my $CGscore    = 0;
    my $dnScore    = 0;
    my $consDNLeft = substr( $consensus, $i, 1 );
    my $k          = $i + 1;
    while ( substr( $consensus, $k, 1 ) eq '-' )
    {
      $k++;
      last FLOOP if ( $k >= length( $consensus ) );
    }
    my $consDNRight = substr( $consensus, $k, 1 );
    foreach ( @{$sequences} )
    {
      my $j = $i;
      next if ( $j >= length( $_ ) );
      my $hitDNLeft = substr( $_, $j, 1 );
      my $hitDNRight = "";
      $hitDNRight = substr( $_, $k, 1 )
          if ( $k < length( $_ ) );
      next if (    $hitDNLeft eq " "
                || $hitDNRight eq " " );
      my $hitDN = $hitDNLeft . $hitDNRight;
      $dnScore += $matrix_r->{ $consDNLeft,  $hitDNLeft };
      $dnScore += $matrix_r->{ $consDNRight, $hitDNRight }
          if ( defined $hitDNRight && $hitDNRight ne "" );

      if ( $hitDN eq 'CA' || $hitDN eq 'TG' )
      {
        $CGscore += $CGparam;
      } elsif ( $hitDN eq 'TA' )
      {
        $CGscore += $TAparam;
      } elsif ( $hitDN =~ /T[CT]/ )
      {

        # in other words; C->T transition scores +2
        # transversion scored normally
        $CGscore += 2 + ( $matrix_r->{ "G", $hitDNRight } );
      } elsif ( $hitDN =~ /[AG]A/ )
      {
        $CGscore += 2 + ( $matrix_r->{ "C", $hitDNLeft } );

        # same as above
      } else
      {
        $CGscore += $matrix_r->{ "C", $hitDNLeft };
        $CGscore += $matrix_r->{ "G", $hitDNRight }
            if ( defined $hitDNRight && $hitDNRight ne "" );
      }
    }
    if ( $CGscore > $dnScore )
    {
      substr( $consensus, $i, 1 ) = 'C';
      substr( $consensus, $k, 1 ) = 'G';
    }
  }

  return $consensus;
}

##---------------------------------------------------------------------##

=head2 buildConsensusFromArray()

  Use: my $consSeq = $obj->buildConsensusFromArray(  
                               sequences => [ 'AC-CAA', 'AGGCAA' ..],
                               matrix => $matrix,
                               CGParam => ##,
                               TAParam => ##,
                               CGTransParam => ## );

  Refine the consensus sequence given the multiple alignment data.
  Correct for missed CpG calls.  Note: The correction currently 
  assumes a AT bias in the genome ( good for mammals ) in the
  hardcoded lineup matrix.  

=cut

##---------------------------------------------------------------------##
sub buildConsensusFromArray
{
  my %parameters = @_;

  my $myMatrix;

  #
  # This is what boosts the value of the CG
  # consensus comparison if the instance dinucs
  # are CA or TG.
  #
  my $CGparam      = 12;   # TG or CA match is 19, TG <-> CA mismatch -12
                           # Previously set at 14. Seems to overestimate in very
                           #   old elements.
  my $TAparam      = -5;   # TG or CA to TA is -4, so slightly worse than that
                           #   CG -> TA mismatch would have been -8
  my $CGTransParam = 2;    # Adjust scores of transitions/transversion pairs
                           #  that could have arisen from CpG site.

  #         A   R   G   C   Y   T   K   M   S   W   N   X   Z
  my @alphaArray = (
    qw(  9   0  -8 -15 -16 -17 -13  -3 -11  -4  -2  -7  -3 ),
    qw(  2   1   1 -15 -15 -16  -7  -6  -6  -7  -2  -7  -3 ),
    qw( -4   3  10 -14 -14 -15  -2  -9  -2  -9  -2  -7  -3 ),
    qw(-15 -14 -14  10   3  -4  -9  -2  -2  -9  -2  -7  -3 ),
    qw(-16 -15 -15   1   1   2  -6  -7  -6  -7  -2  -7  -3 ),
    qw(-17 -16 -15  -8   0   9  -3 -13 -11  -4  -2  -7  -3 ),
    qw(-11  -6  -2 -11  -7  -3  -2 -11  -6  -7  -2  -7  -3 ),
    qw( -3  -7 -11  -2  -6 -11 -11  -2  -6  -7  -2  -7  -3 ),
    qw( -9  -5  -2  -2  -5  -9  -5  -5  -2  -9  -2  -7  -3 ),
    qw( -4  -8 -11 -11  -8  -4  -8  -8 -11  -4  -2  -7  -3 ),
    qw( -2  -2  -2  -2  -2  -2  -2  -2  -2  -2  -1  -7  -3 ),
    qw( -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -7  -3 ),
    qw( -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3  -3 )
  );
  my $alphabet_r = [ qw( A   R   G   C   Y   T   K   M   S   W   N   X   Z ) ];
  my $matrix_r   = {};
  for ( my $i = 0 ; $i < scalar( @{$alphabet_r} ) ; $i++ )
  {
    for ( my $j = 0 ; $j < scalar( @{$alphabet_r} ) ; $j++ )
    {
      $matrix_r->{ $alphabet_r->[ $i ], $alphabet_r->[ $j ] } =
          $alphaArray[ ( $i * scalar( @{$alphabet_r} ) ) + $j ];
    }
  }

  # Supplement score matrix with additional row/col indicating how
  # to score gap "-" characters.
  foreach my $n ( @$alphabet_r )
  {
    $matrix_r->{ $n, '-' } = $matrix_r->{ '-', $n } = -6;
  }
  push @$alphabet_r, '-';
  $matrix_r->{ '-', '-' } = 3;

  # Allow the user to override the lineup matrix defaults
  if ( defined $parameters{'matrix'} )
  {
    $myMatrix   = $parameters{'matrix'};
    $alphabet_r = $myMatrix->{'alphabetArray'};
    $matrix_r   = $myMatrix->{'matrixHash'};

    # Double check that the "-" characters are scored!
    croak $CLASS
        . "::buildConsensusFromArray: Missing CGParam parameter!\n"
        . "This parameter is required if a matrix is supplied\n"
        if ( !defined $parameters{'CGParam'} );
    $CGparam = $parameters{'CGParam'};

    croak $CLASS
        . "::buildConsensusFromArray: Missing TAParam parameter!\n"
        . "This parameter is required if a matrix is supplied\n"
        if ( !defined $parameters{'TAParam'} );
    $TAparam = $parameters{'TAParam'};
    croak $CLASS
        . "::buildConsensusFromArray: Missing CGTransParam\n"
        . "parameter! This parameter is required if a matrix is supplied\n"
        if ( !defined $parameters{'CGTransParam'} );
    $CGTransParam = $parameters{'CGTransParam'};
  }

  #
  # Build up a profile of these multiply aligned sequences
  #
  my $sequences = $parameters{'sequences'};
  my @profile   = ();
  foreach my $seq ( @{$sequences} )
  {
    my $i = 0;
    grep $profile[ $i++ ]{$_}++, split( '', $seq );
  }

  #
  # Generate a first pass consensus
  #   - Highest matrix score wins
  #
  my $consensus = '';
  my @cScore    = ();
  my $i         = 0;
  foreach $i ( 0 .. $#profile )
  {
    my $maxScore = -1000000;
    my $n        = '';

    foreach $a ( @$alphabet_r )
    {
      my $score = 0;
      foreach $b ( keys %{ $profile[ $i ] } )
      {
        next if ( $b eq " " );
        croak $CLASS
            . "::buildConsensusFromArray: Matrix alphabet doesn't include\n"
            . "the letters: $a, $b\n"
            if ( !defined $matrix_r->{ $a, $b } );
        $score += $profile[ $i ]{$b} * $matrix_r->{ $a, $b };
      }
      if ( $score > $maxScore )
      {
        $n        = $a;
        $maxScore = $score;
      }
    }
    $consensus .= $n;
    push @cScore, $maxScore;
  }

  #
  #   go through the consensus and consider changing each dinucleotide
  #   to a 'CG'
  #
FLOOP: foreach $i ( 0 .. length( $consensus ) - 2 )
  {
    next if ( substr( $consensus, $i, 1 ) eq '-' );
    my $CGscore = 0;
    my $dnScore = 0;

    # Gather di-nucleotide pair and set consDNLeft/consDNRight accordingly.
    #    NOTE: Gaps between pair in consensus are ok.  ie.
    #          CG, C---G, C-G are all considered
    my $consDNLeft = substr( $consensus, $i, 1 );
    my $k = $i + 1;
    while ( substr( $consensus, $k, 1 ) eq '-' )
    {
      $k++;
      last FLOOP if ( $k >= length( $consensus ) );
    }
    my $consDNRight = substr( $consensus, $k, 1 );
    foreach ( @{$sequences} )
    {
      my $j = $i;
      next if ( $j >= length( $_ ) );
      my $hitDNLeft = substr( $_, $j, 1 );
      my $hitDNRight = "";
      $hitDNRight = substr( $_, $k, 1 )
          if ( $k < length( $_ ) );
      next if (    $hitDNLeft eq " "
                || $hitDNRight eq " " );
      my $hitDN = $hitDNLeft . $hitDNRight;

      # Recalculate the score of the consensus ( excluding gap characters )
      $dnScore += $matrix_r->{ $consDNLeft,  $hitDNLeft };
      $dnScore += $matrix_r->{ $consDNRight, $hitDNRight }
          if ( defined $hitDNRight && $hitDNRight ne "" );
      ##
      ## Method better at younger families.  This table is based
      ## on the fixed linup matrix provided in this subroutine.
      ##
      ##  CpG Hypothesis   Obs   Score   Description
      ##  -----------------------------------------------------------
      ##  ex1              TG      +12    Direct result of current strand
      ##                                  CpG deaminating the C and converting
      ##                                  to a TG.
      ##  ex2              CA      +12    Indirect result of CpG on opp strand
      ##                                  converting to TG and an incorrect
      ##                                  repair of the current strand.
      ##  ex3              TA      -5     Two step result.  CpG -> TG followed
      ##                                  by a common transition of either
      ##                                  forward strand TG->TA or reverse
      ##                                  strand CA->TA.
      ##  ex4              TT      -13    Normal transition C->T followed by
      ##                                  transversion.  Scored as +2 for
      ##                                  transition and matrix value for
      ##                                  transversion: Matrix G->T = -15
      ##                                  [+2] = -13. Could have started as
      ##                                  a CG->TG->TT
      ##  ex5              TC      -13    (dito) Matrix G->C = -15 = -13
      ##  ex6              AA      -13    (dito)Matrix C->A = -15 = -13
      ##  ex7              GA      -13    (dito)Matrix C->G = -15 = -13
      ##  ex8              GT      -30    Normal matrix score C->G = -15,
      ##                                  G->T = -15, Total = -30
      ##  ex9              AG      -5     Normal matrix score C->A = -15,
      ##                                  G->G = 10, Total = -5
      ##  ...
      ##  ...
      if ( $hitDN eq 'CA' || $hitDN eq 'TG' )
      {
        $CGscore += $CGparam;
      } elsif ( $hitDN eq 'TA' )
      {
        $CGscore += $TAparam;
      } elsif ( $hitDN =~ /T[CT]/ )
      {

        # in other words; C->T transition scores +2
        # transversion scored normally
        $CGscore += $CGTransParam + ( $matrix_r->{ "G", $hitDNRight } );
      } elsif ( $hitDN =~ /[AG]A/ )
      {
        $CGscore += $CGTransParam + ( $matrix_r->{ "C", $hitDNLeft } );

        # same as above
      } else
      {
        $CGscore += $matrix_r->{ "C", $hitDNLeft };
        $CGscore += $matrix_r->{ "G", $hitDNRight }
            if ( defined $hitDNRight && $hitDNRight ne "" );
      }
    }
    if ( $CGscore > $dnScore )
    {
      substr( $consensus, $i, 1 ) = 'C';
      substr( $consensus, $k, 1 ) = 'G';
    }
  }

  return $consensus;
}

##---------------------------------------------------------------------##

=head getCoverage()

  Use: my @coverageArray = $obj->getCoverage();

  Obtain an array of coverage depth at each multiple alignment 
  position.

=cut

##---------------------------------------------------------------------##
sub getCoverage
{
  my $object = shift;

  my @coverage = ();
  my @profile  = $object->profile;
  foreach my $i ( 0 .. $object->getGappedReferenceLength() - 1 )
  {
    my $depth = 0;
    foreach my $b ( keys %{ $profile[ $i ] } )
    {
      $depth += $profile[ $i ]{$b};
    }
    push @coverage, $depth;
  }

  return ( @coverage );

}

##---------------------------------------------------------------------##

=head2 consensus()

  Use: my $consSeq = $obj->consensus( [inclRef => 1] );

  Refine the consensus sequence given the multiple alignment data.
  Correct for missed CpG calls.  Note: The correction currently 
  assumes a AT bias in the genome ( good for mammals ) in the
  hardcoded lineup matrix.  

=cut

##---------------------------------------------------------------------##
sub consensus
{
  my $object     = shift;
  my %parameters = @_;

  my $inclRef = 0;
  $inclRef = 1 if ( $parameters{'inclRef'} );

  my @seqs = ();
  if ( $inclRef )
  {
    push @seqs, $object->getReferenceSeq();
  }
  for ( my $i = 0 ; $i < $object->getNumAlignedSeqs() ; $i++ )
  {
    my $numShifted = $object->getAlignedStart( $i );
    push @seqs, " " x ( $numShifted ) . $object->getAlignedSeq( $i );
  }
  my $consensus = buildConsensusFromArray( sequences => \@seqs );

  return $consensus;
}

##---------------------------------------------------------------------##
## Use:
##
##
##  Returns
##
##
##  NOTE: Written by Arnie Kas
##---------------------------------------------------------------------##
sub profile
{
  my $object     = shift;
  my %parameters = @_;

  my $inclRef = 0;
  $inclRef = 1 if ( $parameters{'inclRef'} );

  my @list = @{ $object->list };
  shift @list if ( !$inclRef );
  my @profile = ();
  my $seq     = ();
  foreach $seq ( @list )
  {
    my $start = $seq->{start};
    my $i     = 0;
    grep $profile[ $start + $i++ ]{$_}++, split( '', $seq->{seq} );
  }
  return @profile;
}

sub createGreedyTilingPath
{
  my $object = shift;

  my @hitArrayCollection = ();
  foreach my $n ( 0 .. $object->getNumAlignedSeqs() - 1 )
  {
    $hitArrayCollection[ $n - 1 ] = [
                                      $object->instRefStart( $n ),
                                      $object->instRefEnd( $n ),
                                      $object->getAlignedDiv( $n )
    ];
  }
  serializeOUT( \@hitArrayCollection, "test.out" );

  my $i               = 0;     # Basic loop counter
  my $j               = 0;     # Basic loop counter
  my @queryHitArray   = ();    # Array to store one record
                               #  of the hitArrayCollectionRef
  my @subjectHitArray = ();    # Array to store one record
                               #  of the newHitArrayCollection

  #
  # Sort hitArrayCollectionRef by Score field
  #
  #@hitArrayCollection = sort { $b->[0] <=> $a->[0] or
  #                             $a->[2] <=> $b->[2] } @hitArrayCollection;
  @hitArrayCollection = sort {
    $b->[ 0 ] <=> $a->[ 0 ]
        or ( $a->[ 0 ] - $a->[ 1 ] ) <=> ( $b->[ 0 ] - $b->[ 1 ] )
  } @hitArrayCollection;

  #
  # Pull out hits and include in index if it doesn't overlap
  # any hits already pulled
  #
  my $level = 10000;
  while ( $#hitArrayCollection > 0 )
  {
    my @newHitArrayCollection = ();    # Final result of this routine is stored
                                       #  here before being returned
    for ( $i = 0 ; $i <= $#hitArrayCollection ; $i++ )
    {
      @queryHitArray = @{ $hitArrayCollection[ $i ] };

      for ( $j = 0 ; $j <= $#newHitArrayCollection ; $j++ )
      {
        @subjectHitArray = @{ $newHitArrayCollection[ $j ] };
        last
            if (
                 (
                      $queryHitArray[ 0 ] >= $subjectHitArray[ 0 ]
                   && $queryHitArray[ 0 ] <= $subjectHitArray[ 1 ]
                 )
                 || (    $queryHitArray[ 1 ] >= $subjectHitArray[ 0 ]
                      && $queryHitArray[ 1 ] <= $subjectHitArray[ 1 ] )
                 || (    $subjectHitArray[ 0 ] >= $queryHitArray[ 0 ]
                      && $subjectHitArray[ 0 ] <= $queryHitArray[ 1 ] )
            );
      }
      if ( $j == $#newHitArrayCollection + 1 )
      {

        # does not overlap any previous entries
        $newHitArrayCollection[ $j ] = $hitArrayCollection[ $i ];
        my @line = splice( @hitArrayCollection, $i, 1 );
        print ""
            . $line[ 0 ][ 0 ]
            . "\t$level\t"
            . $line[ 0 ][ 0 ] . "\t"
            . $line[ 0 ][ 1 ] . "\n";
      }
    }
    $level--;
  }

 #
 # Sort hitIDArray by hitArrayCollection start position
 #
 #@newHitArrayCollection = sort { $a->[0] <=> $b->[0] } @newHitArrayCollection;�
 #return (\@newHitArrayCollection);

}

1;

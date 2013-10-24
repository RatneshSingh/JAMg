/*****************************************************************************\
 * Filename : fasta.hh
 * Authors  : Mario Stanke
 *
 *
 * Date       |   Author              |  Changes
 *------------|-----------------------|----------------------------------------
 * 01.09.2012 | Mario Stanke          | Creation of the file
\******************************************************************************/

#ifndef _FASTA_HH
#define _FASTA_HH

#include <iostream>
#include <fstream>


void readOneFastaSeq(std::ifstream &ifstrm, char* &sequence, char* &name, int &length);

#endif   //  _FASTA_HH


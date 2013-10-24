/**********************************************************************
 * file:    orthoexon.cc
 * licence: Artistic Licence, see file LICENCE.TXT or 
 *          http://www.opensource.org/licenses/artistic-license.php
 * descr.:  maintains orthologous exons for comparative gene prediction
 * authors: Stefanie König
 *
 * date    |   author      |  changes
 * --------|---------------|------------------------------------------
 * 09.03.12|Stefanie König | creation of the file
 **********************************************************************/

// project includes
#include "orthoexon.hh"
#include "exoncand.hh"
#include "projectio.hh"
#include "orthograph.hh"
#include "types.hh"

#include <fstream>
#include <iostream>


OrthoExon::OrthoExon(){
    orthoex.resize(OrthoGraph::numSpecies);
}
//copy with permutation of vector entries
OrthoExon::OrthoExon(const OrthoExon& other, const vector<size_t> &permutation){
    orthoex.resize(other.orthoex.size());
    for(size_t pos = 0; pos < orthoex.size(); pos++){
	if (other.orthoex[pos]){
	    orthoex[permutation[pos]] = other.orthoex[pos];
	}
    }
}

list<OrthoExon> readOrthoExons(string filename){

    list<OrthoExon> all_orthoex;

    ifstream istrm; 
    istrm.open(filename.c_str(), ifstream::in);
    if (istrm) {
	int nspecies;
	string species;
	vector<size_t> permutation;
	istrm >> goto_line_after( "[SPECIES]");
	istrm >> comment >> nspecies;
	if (nspecies != OrthoGraph::numSpecies){
	    throw ProjectError("readOrthoExons: number of species in " + filename + 
			       " is " + itoa(nspecies) + ". Number of species in treefile is " + itoa(OrthoGraph::numSpecies));
	}
	istrm >> comment;
	for (int i = 0; i < nspecies; i++){
	    istrm >> species;
	    size_t pos = OrthoGraph::tree->getVectorPositionSpecies(species);
	    if (pos == OrthoGraph::numSpecies){
		throw ProjectError("readOrthoExons: species name in " + filename + 
				   " is not a species name in treefile.");
	    }
	    permutation.push_back(pos);
	}
	vector<string> chr(nspecies);
	while(istrm){
	    istrm >> goto_line_after( "[CHR]") >> comment;
	    for (int i = 0; i < nspecies; i++){
		istrm >> chr[permutation[i]];
	    } 
	    cout << endl;
	    istrm >> goto_line_after( "[ORTHOEX]");
	    istrm >> comment;
	    while( istrm >> comment >> ws, istrm && istrm.peek() != '[' ){
		OrthoExon ex_tuple;
		istrm >> ex_tuple;
		all_orthoex.push_back(OrthoExon(ex_tuple, permutation));
	    }
	} 
    }
    else
	throw ProjectError("readOrthoExons: Could not open this file!");

    return all_orthoex;
    }

void writeOrthoExons(const list<OrthoExon> &all_orthoex){
    cout << "# orthologous exons\n" << "#\n" <<"[SPECIES]\n" << "# number of species" << endl;
    cout << OrthoGraph::numSpecies << endl;
    cout << "# species names" << endl;
    for (size_t i = 0; i < OrthoGraph::numSpecies; i++){
	cout << OrthoGraph::tree->species[i] << "\t";
    }
    cout << endl;
    cout << "#[ORTHOEX]" << endl;
    for(list<OrthoExon>::const_iterator it = all_orthoex.begin(); it != all_orthoex.end(); it++){
	cout << *it << endl;
    }
}

ostream& operator<<(ostream& ostrm, const OrthoExon &ex_tuple){

  
    ostrm << stateTypeIdentifiers[ (ex_tuple.orthoex.at(0)->getStateType())];
    for (int i = 0; i < ex_tuple.orthoex.size(); i++){
	if (ex_tuple.orthoex.at(i) == NULL){
	    ostrm << "\t" << 0 << "\t" << 0 << "\t";
	}
	else{
	    ostrm << "\t" << ex_tuple.orthoex.at(i)->begin+1 << "\t" << ex_tuple.orthoex.at(i)->end - ex_tuple.orthoex.at(i)->begin + 1;
	}
    }
    return ostrm;
}

istream& operator>>(istream& istrm, OrthoExon& ex_tuple){

    string exontype;
    long int begin, length;

    istrm >> exontype;
    for (int i = 0; i < OrthoGraph::numSpecies; i++){
	istrm >> begin >> length;
	if (begin != 0 && length != 0){
	    ExonCandidate *exoncand = new ExonCandidate(toExonType(exontype.c_str()), begin-1, begin+length-2);
	    ex_tuple.orthoex[i] = exoncand;
	}
    }
    return istrm;
}

/**********************************************************************
 * file:    geneMSA.cc
 * licence: Artistic Licence, see file LICENCE.TXT or 
 *          http://www.opensource.org/licenses/artistic-license.php
 * descr.:  Generation of exon candidates
 * author:  Alexander Gebauer
 *
 * date    |   author           |  changes
 * --------|--------------------|------------------------------------------
 * 04.04.12| Alexander Gebauer  | creation of the file
 **********************************************************************/

#include "geneticcode.hh"
#include "exoncand.hh"
#include "genomicMSA.hh"
#include "geneMSA.hh"
#include "orthoexon.hh"
#include "intronmodel.hh"
#include "namgene.hh"
#include <fstream>
#include <iostream>
#include <string>
#include <sys/time.h>

using namespace std;

PhyloTree *GeneMSA::tree = NULL;
int GeneMSA::utr_range = 1000;
int GeneMSA::orthoExonID = 1;
int GeneMSA::geneRangeID = 1;
vector<int> GeneMSA::exonCandID;
vector<ofstream*> GeneMSA::exonCands_outfiles;
vector<ofstream*> GeneMSA::orthoExons_outfiles;
vector<ofstream*> GeneMSA::geneRanges_outfiles;
vector<ofstream*> GeneMSA::omega_outfiles;
ofstream *GeneMSA::pamlFile;

string GeneMSA::getName(int speciesIdx) {
    for (list<AlignmentBlock*>::iterator it=this->alignment.begin(); it!=this->alignment.end(); it++) {
        if ((*it)->alignSpeciesTuple.at(speciesIdx)!=NULL) {
            return (*it)->alignSpeciesTuple.at(speciesIdx)->name;
        }
    }
    return "";
}

long int GeneMSA::getSeqIDLength(int speciesIdx) {
    for (list<AlignmentBlock*>::iterator it=this->alignment.begin(); it!=this->alignment.end(); it++) {
        if ((*it)->alignSpeciesTuple.at(speciesIdx)!=NULL) {
            return (*it)->alignSpeciesTuple.at(speciesIdx)->seqID.second;
        }
    }
    return 0;
}

string GeneMSA::getSeqID(int speciesIdx) {
    for (list<AlignmentBlock*>::iterator it=this->alignment.begin(); it!=this->alignment.end(); it++) {
        if ((*it)->alignSpeciesTuple.at(speciesIdx)!=NULL) {
            return (*it)->alignSpeciesTuple.at(speciesIdx)->seqID.first;
        }
    }
    return "";
}

Strand GeneMSA::getStrand(int speciesIdx) {
    for (list<AlignmentBlock*>::iterator it=this->alignment.begin(); it!=this->alignment.end(); it++) {
        if ((*it)->alignSpeciesTuple.at(speciesIdx)!=NULL) {
            return (*it)->alignSpeciesTuple.at(speciesIdx)->strand;
        }
    }
    return STRAND_UNKNOWN;
}

int GeneMSA::getStart(int speciesIdx) {
    for (list<AlignmentBlock*>::iterator it=this->alignment.begin(); it!=this->alignment.end(); it++) {
        if ((*it)->alignSpeciesTuple.at(speciesIdx)!=NULL) {
            if (this->getStrand(speciesIdx)==plusstrand) {
                return (*it)->alignSpeciesTuple.at(speciesIdx)->offset - utr_range;
            } else {
                for (list<AlignmentBlock*>::reverse_iterator rit=this->alignment.rbegin(); rit!=this->alignment.rend(); rit++) {
                    if ((*rit)->alignSpeciesTuple.at(speciesIdx)!=NULL) {
                        return ((*it)->alignSpeciesTuple.at(speciesIdx)->seqID.second) - ((*rit)->alignSpeciesTuple.at(speciesIdx)->offset)
                                - ((*rit)->alignSpeciesTuple.at(speciesIdx)->seqLen) - utr_range;
                    }
                }
            }
        }
    }
    return -1;
}

int GeneMSA::getEnd(int speciesIdx){
    for (list<AlignmentBlock*>::reverse_iterator rit=this->alignment.rbegin(); rit!=this->alignment.rend(); rit++) {
        if ((*rit)->alignSpeciesTuple.at(speciesIdx)!=NULL) {
            if (this->getStrand(speciesIdx)==plusstrand) {
                return (*rit)->alignSpeciesTuple.at(speciesIdx)->offset + (*rit)->alignSpeciesTuple.at(speciesIdx)->seqLen - 1 + utr_range;
            } else {
                for (list<AlignmentBlock*>::iterator it=this->alignment.begin(); it!=this->alignment.end(); it++) {
                    if ((*it)->alignSpeciesTuple.at(speciesIdx)!=NULL) {
                        return ((*rit)->alignSpeciesTuple.at(speciesIdx)->seqID.second) - ((*it)->alignSpeciesTuple.at(speciesIdx)->offset + 1) + utr_range;
                    }
                }
            }
        }
    }
    return 0;
}

int GeneMSA::getGFF3FrameForExon(ExonCandidate *ec) {
    if (ec->type <= 7) {
        return mod3(3-(exonTypeReadingFrames[ec->type] - (ec->end - ec->begin + 1)));
    } else if ((ec->type == 8) || (ec->type >= 13)) {
        return 0;
    } else if (ec->type == 9) {
        return mod3(ec->end - ec->begin + 1);
    } else {
        return mod3(1 + exonTypeReadingFrames[ec->type] + (ec->end - ec->begin + 1));
    }
}

list<ExonCandidate*>* GeneMSA::getExonCands(int speciesIdx) {
    if (this->exoncands.at(speciesIdx)!=NULL) {
        return exoncands.at(speciesIdx);
    } else {
        return NULL;
    }
}

list<OrthoExon> GeneMSA::getOrthoExons(){
    if (!this->orthoExonsList.empty()) {
        return this->orthoExonsList;
    } else {
        cout<<" no orthologue exons in this part of the alignment found"<<endl;
        return this->orthoExonsList;  // list is empty
    }
}

// compare function to find the correct reference value to compute the aligned position
bool compRealPos (int a, block b) {
    return (a < b.begin);
}

bool compCmpStarts (int a, int *b) {
    if (b!=NULL) {
        return (a < *b);
    } else {
        return false;
    }
}

// compare function to find the correct aligned position of a base
bool compAlignedPos (int a, block b) {
    return (a < b.begin - b.previousGaps);
}

// compare function to sort the exon candidates by startposition
bool compBegin (ExonCandidate* a, ExonCandidate* b) {
    if (a->begin != b->begin) {
        return (a->begin<b->begin);
    } else  if (a->end != b->end) {
        return (a->end<b->end);
    } else {
        return (a->type<b->type);
    }
}

string GeneMSA::reverseString(string text) {
    int i = 0;
    int n = text.length();
    while (i < (n/2)) {
        char c;
        c = (text[i]);
        text[i] = text[n-i-1];
        text[n-i-1] = c;
        i++;
    }
    return text;
}

// adds the keys to the map function
map<string,ExonCandidate*>* GeneMSA::addToHash(list<ExonCandidate*> *ec) {
    map<string, ExonCandidate*> *hashCandidates =new  map<string, ExonCandidate*>;
    if (!(ec->empty())) {
        for (list<ExonCandidate*>::iterator lit=ec->begin(); lit!=ec->end(); lit++) {
            (*hashCandidates)[(*lit)->key()] = *lit;
        }
        return hashCandidates;
    } else {
        return NULL;
    }
}

// computes the score for the splice sites of an exon candidate
Double GeneMSA::computeSpliceSiteScore(Double exonScore, Double minProb, Double maxProb) {
    Double score = 0;
    score = (log(exonScore/minProb)/log(maxProb/minProb));
    return score;
}

// computes the exon candidates of a dna sequence
void GeneMSA::createExonCands(const char *dna, double assmotifqthresh, double assqthresh, double dssqthresh){
    int n = strlen(dna);
    int max_exon_length = 12000;
    int frame;
    Double p;
    list<int> exonStart;
    list<int> exonRCStop;
    list< pair<int, Double> > exonASS;
    list< pair<int, Double> > exonRDSS;
    ExonCandidate *ec;
    list<ExonCandidate*> *candidates=new list<ExonCandidate*>;
    Properties::assignProperty("/CompPred/assmotifqthresh", assmotifqthresh);
    Properties::assignProperty("/CompPred/assqthresh", assqthresh);
    Properties::assignProperty("/CompPred/dssqthresh", dssqthresh);
    Double assminprob = IntronModel::assBinProbs.getMinProb(assqthresh) * IntronModel::getAssMotifProbThreshold(assmotifqthresh);
    Double dssminprob = IntronModel::dssBinProbs.getMinProb(dssqthresh);
    Double assmaxprob = IntronModel::assBinProbs.getMinProb(0.99) * IntronModel::getAssMotifProbThreshold(0.9999);
    Double dssmaxprob = IntronModel::dssBinProbs.getMinProb(0.99);

    OpenReadingFrame orf(dna, max_exon_length, n);
    // preprocessing all left coordinates of an exon candidate interval
    for (int i=0; i<=n - 1; i++) {
        pair<int, Double> ssWithScore;
        // positions of all startcodons "atg"
        if (onStart(dna+i)) {
            exonStart.push_back(i + 1);
        }
        // positons of all ASSs "ag"
        if (onASS(dna+i) && (i + Constant::ass_whole_size() - Constant::ass_start < n)) {
            p = IntronModel::aSSProb(i - Constant::ass_upwindow_size - Constant::ass_start, true);
            if (p >= assminprob ) {
                ssWithScore.first = i;
                ssWithScore.second = computeSpliceSiteScore(p, assminprob, assmaxprob);
                exonASS.push_back(ssWithScore);
            }
        }
        // positions of all reverse DSS "ac"
        if (onRDSS(dna+i) && (i + Constant::dss_whole_size() - Constant::dss_end < n)) {
            p = IntronModel::dSSProb(i - Constant::dss_end, false);
            if (p >= dssminprob) {
                ssWithScore.first = i;
                ssWithScore.second = computeSpliceSiteScore(p, dssminprob, dssmaxprob);
                exonRDSS.push_back(ssWithScore);
            }
        }
        // positions of all reverse complementary stop codons, usually "cta, tta, tca"
        if (GeneticCode::isRCStopcodon(dna+i)) {
            exonRCStop.push_back(i);
        }
    }
    list<int>::reverse_iterator ritStart = exonStart.rbegin();
    list<int>::reverse_iterator ritStart_cur = ritStart;
    list< pair<int, Double> >::reverse_iterator ritASS = exonASS.rbegin();
    list< pair<int, Double> >::reverse_iterator ritASS_cur = ritASS;
    list< pair<int, Double> >::reverse_iterator ritRDSS = exonRDSS.rbegin();
    list< pair<int, Double> >::reverse_iterator ritRDSS_cur = ritRDSS; // remember iterator over iterations of the loop of the right end
    list<int>::reverse_iterator ritRCStop = exonRCStop.rbegin();
    list<int>::reverse_iterator ritRCStop_cur = ritRCStop;

    for (int i = n-1; i >= 2; i--) {
        // computing single genes on the forward strand with at least Constant::min_coding_len
        if (GeneticCode::isStopcodon(dna+i)) {
            ritStart = ritStart_cur;
            while ((i < *ritStart) && (ritStart != exonStart.rend())){
                ritStart++;
            }
            ritStart_cur = ritStart;
            int lmb = orf.leftmostExonBegin(0, i, true);
            while ((lmb <= *ritStart) && (i - *ritStart <= max_exon_length) && (ritStart != exonStart.rend())) {
                if ((i - *ritStart >= Constant::min_coding_len) && ((i - *ritStart+1)%3 == 0)) {
                    ec = new ExonCandidate;
                    ec->begin = *ritStart - 1;
                    ec->end = i-1;
                    ec->type = singleGene;
                    candidates->push_back(ec);
                }
                ritStart++;
            };
        }

        // computing initial exons on the forward strand with at least startcodon plus base
        if (onDSS(dna + i) && (i + Constant::dss_whole_size() - Constant::dss_start  < n)) {
            p = IntronModel::dSSProb(i - Constant::dss_start,true);
            for (frame=0; frame<=2; frame++) {
                ritStart=ritStart_cur;
                while ((i<*ritStart)&&(ritStart!=exonStart.rend())){
                    ritStart++;
                }
                ritStart_cur = ritStart;
                int lmb = orf.leftmostExonBegin(frame,i,true);
                while((lmb <= *ritStart) && (i-*ritStart<=max_exon_length) && (ritStart!=exonStart.rend())) {
                    if ((i - *ritStart>=3) && ((i-*ritStart+1)%3==frame) && (p >= dssminprob)) {
                        ec = new ExonCandidate;
                        ec->begin = *ritStart - 1;
                        ec->end = i - 1;
                        ec->dssScore = computeSpliceSiteScore(p, dssminprob, dssmaxprob);
                        if (frame == 0) {
                            ec->type = initial_0;
                        } else if (frame == 1) {
                            ec->type = initial_1;
                        } else {
                            ec->type = initial_2;
                        }
                        candidates->push_back(ec);
                    }
                    ritStart++;
                };
            }

            // computing internals on the forward strand with at least one codon
            for (frame=0; frame<=2; frame++) {
                ritASS=ritASS_cur;
                while ((i<(*ritASS).first)&&(ritASS!=exonASS.rend())){
                    ritASS++;
                }
                ritASS_cur = ritASS;
                int lmb = orf.leftmostExonBegin(frame,i,true);
                while(lmb <= (*ritASS).first && i-(*ritASS).first <= max_exon_length && ritASS != exonASS.rend()) {
                    if ((i-(*ritASS).first>=5) && (p >= dssminprob)) {
                        ec = new ExonCandidate;
                        ec->begin = (*ritASS).first + 2;
                        ec->end = i - 1;
                        ec->assScore = (*ritASS).second;
                        ec->dssScore = computeSpliceSiteScore(p, dssminprob, dssmaxprob);
                        if (frame == 0) {
                            ec->type = internal_0;
                        } else if (frame==1) {
                            ec->type = internal_1;
                        } else {
                            ec->type = internal_2;
                        }
                        candidates->push_back(ec);
                    }
                    ritASS++;
                };
            }
        }

        // computing terminals on the forward strand with at least one base stopcodon
        if (GeneticCode::isStopcodon(dna+i)) {
            for (frame=0; frame<=2; frame++) {
                ritASS=ritASS_cur;
                while ((i<(*ritASS).first)&&(ritASS!=exonASS.rend())){
                    ritASS++;
                }
                ritASS_cur = ritASS;
                while ((i-(*ritASS).first <= max_exon_length)&&(ritASS!=exonASS.rend())) {
                    if ((i-(*ritASS).first>=3) && ((i-(*ritASS).first + 1)%3==frame) && ((*ritASS).first>=orf.leftmostExonBegin(0,i,true))) {
                        ec = new ExonCandidate;
                        ec->begin = (*ritASS).first + 2;
                        ec->end = i -1;
                        ec->assScore = (*ritASS).second;
                        ec->type = terminal_exon;
                        candidates->push_back(ec);
                    }
                    ritASS++;
                };
            }
        }

        // computing single genes on the reverse strand with at least Constant::min_coding_len
        if (onRStart(dna+i)) {
            ritRCStop=ritRCStop_cur;
            while ((i < *ritRCStop) && (ritRCStop != exonRCStop.rend())){
                ritRCStop++;
            }
            ritRCStop_cur=ritRCStop;
            while ((i-*ritRCStop <= max_exon_length) && (ritRCStop!=exonRCStop.rend())) {
                if ((i-*ritRCStop)%3 == 0) {
                    if ((i-*ritRCStop) >= Constant::min_coding_len) {
                        ec = new ExonCandidate;
                        ec->begin=*ritRCStop +3;
                        ec->end=i + 2;
                        ec->type=rsingleGene;
                        candidates->push_back(ec);
                        break;
                    } else {
                        break;
                    }
                } else {
                    ritRCStop++;
                }
            };
        }

        // computing initials on the reverse strand with at least start codon plus base
        if (onRStart(dna+i)) {
            for (frame=0; frame<=2; frame++) {
                ritRDSS=ritRDSS_cur;
                while ((i<(*ritRDSS).first)&&(ritRDSS!=exonRDSS.rend())){
                    ritRDSS++;
                }
                ritRDSS_cur=ritRDSS;
                int lmb = orf.leftmostExonBegin(2,i,false);
                while((lmb<=(*ritRDSS).first+2)&&(i-(*ritRDSS).first<=max_exon_length)&&(ritRDSS!=exonRDSS.rend())) {
                    if ((i-(*ritRDSS).first>=2)&&((i+1-(*ritRDSS).first)%3==frame)) {
                        ec = new ExonCandidate;
                        ec->begin=(*ritRDSS).first + 2;
                        ec->end=i + 2;
                        ec->dssScore = (*ritRDSS).second;
                        ec->type=rinitial_exon;
                        candidates->push_back(ec);
                    }
                    ritRDSS++;
                };
            }
        }

        // computing internals on the reverse strand with at least a codon
        if (onRASS(dna+i) && (i + Constant::ass_upwindow_size + Constant::ass_whole_size() - Constant::ass_start < n)) {
            p = IntronModel::aSSProb(i-Constant::ass_end, false);
            for (frame=0; frame<=2; frame++) {
                ritRDSS=ritRDSS_cur;
                while ((i<(*ritRDSS).first)&&(ritRDSS!=exonRDSS.rend())){
                    ritRDSS++;
                }
                ritRDSS_cur=ritRDSS;
                int lmb = orf.leftmostExonBegin(frame,i,false);
                while((lmb<=(*ritRDSS).first)&&(i-(*ritRDSS).first<=max_exon_length)&&(ritRDSS!=exonRDSS.rend())) {
                    if (i-(*ritRDSS).first>=5 && (p >= assminprob)) {
                        ec = new ExonCandidate;
                        ec->begin=(*ritRDSS).first + 2;
                        ec->end=i - 1;
                        ec->dssScore = (*ritRDSS).second;
                        ec->assScore = computeSpliceSiteScore(p, assminprob, assmaxprob);
                        if (frame==0) {
                            ec->type=rinternal_0;
                        } else if (frame==1) {
                            ec->type=rinternal_1;
                        } else {
                            ec->type=rinternal_2;
                        }
                        candidates->push_back(ec);
                    }
                    ritRDSS++;
                };
            }
        }

        // computing terminals on the reverse strand with at least one base plus stopcodon
        if (onRASS(dna+i) && (i + Constant::ass_upwindow_size + Constant::ass_whole_size() - Constant::ass_start < n)) {
            p = IntronModel::aSSProb(i-Constant::ass_end, false);
            for (frame=0; frame<=2; frame++) {
                ritRCStop=ritRCStop_cur;
                while ((i<*ritRCStop)&&(ritRCStop!=exonRCStop.rend())){
                    ritRCStop++;
                }
                ritRCStop_cur=ritRCStop;
                while ((i-*ritRCStop <= max_exon_length) && (ritRCStop!=exonRCStop.rend())) {
                    if (i-*ritRCStop == 3) {
                        break;
                    }
                    if ((i-*ritRCStop>=4) && ((i-*ritRCStop)%3==frame) && (p >= assminprob)) {
                        ec = new ExonCandidate;
                        ec->begin=*ritRCStop+3;
                        ec->end=i - 1;
                        ec->assScore = computeSpliceSiteScore(p, assminprob, assmaxprob);
                        if (frame==0) {
                            ec->type=rterminal_2;
                        } else if (frame==1) {
                            ec->type=rterminal_1;
                        } else {
                            ec->type=rterminal_0;
                        }
                        candidates->push_back(ec);
                        break;
                    } else {
                        ritRCStop++;
                    }
                };
            }
        }
    }

    candidates->sort(compBegin);
    this->exoncands.push_back(candidates);
    existingCandidates.push_back(addToHash(candidates));

    /*if (candidates!=NULL) {
        cout<<"possible exons: "<<endl;
        for (list<ExonCandidate*>::iterator lit=candidates->begin(); lit!=candidates->end(); lit++) {
            cout<<"start: "<<(*lit)->begin;
            cout<<"     end: "<<(*lit)->end;
            cout<<"  ass_score: "<<(*lit)->assScore;
            cout<<"  dss_score: "<<(*lit)->dssScore;
            cout<<"     typ "<<(*lit)->type<<endl;
        }
    }*/
    //cout << "thresholds: dssminprob=" << dssminprob << " assminprob=" << assminprob << endl;
}

// computes the aligned position of a base in an alignment and the 'block' where the base is found
pair <int, int> GeneMSA::getAlignedPosition(AlignSeq *as_ptr, int pos) {
    list<block>::iterator it;
    vector<int*>::iterator it_cmpStart;
    pair <int, int> alignedPos;
    it = upper_bound(as_ptr->sequence.begin(), as_ptr->sequence.end(), pos, compAlignedPos);
    it--;
    it_cmpStart = upper_bound(as_ptr->cmpStarts.begin(), as_ptr->cmpStarts.end(), (pos + it->previousGaps), compCmpStarts);
    it_cmpStart--;
    while ((*it_cmpStart)==NULL) {
        it_cmpStart--;
    }
    vector<int*>::difference_type idx = distance(as_ptr->cmpStarts.begin(), it_cmpStart);
    alignedPos.second = idx;
    alignedPos.first = pos + it->previousGaps - (*(*it_cmpStart));
    return alignedPos;
}

// computes the real position of a base dependent on its position in the alignment
int GeneMSA::getRealPosition(AlignSeq *ptr, int pos, int idx) {
    list<block>::iterator it;
    int realPos, alignedPos;
    if (ptr->cmpStarts[idx] != NULL) {
        alignedPos = *ptr->cmpStarts[idx] + pos;
    } else {
        return -1;
    }
    it = upper_bound(ptr->sequence.begin(), ptr->sequence.end(), alignedPos, compRealPos);
    it--;
    realPos = alignedPos - it->previousGaps;
    return realPos;
}

// searches for the ortholog exons of the exon candidates of the reference species
// => any ortholog exon must have an exon in the reference species
void GeneMSA::createOrthoExons(vector<int> offsets) {
    list<AlignmentBlock*>::iterator it_ab;
    list<ExonCandidate*> cands = *getExonCands(0); // exon candidates of reference species
    AlignSeq *as_ptr, *ptr;
    OrthoExon oe;
    string key;
    bool found, hasOrthoExon;

    it_ab = this->alignment.begin();
    for (list<ExonCandidate*>::iterator ec = cands.begin(); ec!=cands.end(); ec++) {
        found = false;
        hasOrthoExon = false;
        if (!oe.orthoex.empty()) {
            oe.orthoex.clear();
            oe.orthoex.resize(this->exoncands.size());
        }
        while ((!found) && (it_ab != this->alignment.end())) {
            if ((*it_ab)->alignSpeciesTuple.at(0)->start > (*ec)->begin + offsets[0] + 1) {
                //cout<<" exon "<<(*ec)->begin + offsets[0] + 1<<".."<<(*ec)->end + offsets[0] + 1<<" is outside (in front of) the aligned range"<<endl;
                found = true;
            } else if (((*it_ab)->alignSpeciesTuple.at(0)->start <= (*ec)->begin + offsets[0] + 1)
                    && ((*it_ab)->alignSpeciesTuple.at(0)->start + (*it_ab)->alignSpeciesTuple.at(0)->seqLen - 1 >= (*ec)->end + offsets[0] + 1)) {
                as_ptr=(*it_ab)->alignSpeciesTuple.at(0);
                if (as_ptr != NULL) {
                    oe.orthoex[0]=(*ec);
                    int alignedPosStart = getAlignedPosition(as_ptr, (*ec)->begin + offsets[0]).first;
                    int idxStart = getAlignedPosition(as_ptr, (*ec)->begin + offsets[0]).second;
                    int alignedPosEnd = getAlignedPosition(as_ptr, (*ec)->end + offsets[0]).first;
                    int idxEnd = getAlignedPosition(as_ptr, (*ec)->end + offsets[0]).second;
                    for (int i=1; i<(*it_ab)->alignSpeciesTuple.size(); i++) { // loop over all non-reference species
                        ptr = (*it_ab)->alignSpeciesTuple.at(i);
                        if (ptr != NULL) {
                            int realStart = getRealPosition(ptr, alignedPosStart, idxStart);
                            int realEnd = getRealPosition(ptr, alignedPosEnd, idxEnd);
                            if ((realStart != -1) && (realEnd != -1) && ((mod3((*ec)->end - (*ec)->begin)) == (mod3(realEnd - realStart)))) {
                                if ((*ec)->type > -1) {
                                    key = (itoa(realStart - offsets[i]) + ":" + itoa(realEnd - offsets[i]) + ":" + itoa((*ec)->type));
                                } else {
                                    key = "no key";
                                }
                                if (existingCandidates[i]!=NULL && existingCandidates[0]!=NULL) {
                                    map<string, ExonCandidate*>::iterator map_it = (*existingCandidates[i]).find(key);
                                    if (map_it != (*existingCandidates[i]).end()) {
                                        if (((*it_ab)->alignSpeciesTuple.at(i)->start <= map_it->second->begin + offsets[i] + 1)
                                                && ((*it_ab)->alignSpeciesTuple.at(i)->start + (*it_ab)->alignSpeciesTuple.at(i)->seqLen - 1 >= map_it->second->end + offsets[i] + 1)) {
                                            oe.orthoex[i] = (map_it->second);
                                            hasOrthoExon = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if (hasOrthoExon) {
                        oe.ID = orthoExonID;
                        orthoExonID++;
                        this->orthoExonsList.push_back(oe);
                    }
                }
                found = true;
            } else {
                it_ab++;
                if ((*it_ab)->alignSpeciesTuple.at(0)->start > (*ec)->begin + offsets[0] + 1) {
                    it_ab--;
                    found=true;
                }
                if (this->getEnd(0) - utr_range < (*ec)->begin + offsets[0] + 1) {
                    cout << " exon "<<(*ec)->begin + offsets[0] + 1<<".."<<(*ec)->end + offsets[0] + 1<<" is outside (behind) the aligned range"<<endl;
                    found = true;
                }
            }
        }
    }
    /*for (list<OrthoExon>::iterator it_oe=orthoExonsList.begin(); it_oe!=orthoExonsList.end(); it_oe++) {
        for (int j=0; j<this->exoncands.size(); j++) {
            if (it_oe->orthoex.at(j)!=NULL && (*it_ab)->alignSpeciesTuple.at(j)!=NULL) {
                cout<<"species: "<<this->getName(j)<<"  ";
                cout<<"start: "<<it_oe->orthoex.at(j)->begin;
                cout<<"     end: "<<it_oe->orthoex.at(j)->end;
                cout<<"     typ "<<it_oe->orthoex.at(j)->type<<endl;
            } else {
                cout<<"species "<<this->getName(j)<<" has no orthologue exon "<<endl;
            }
        }
        cout<<endl;
    }*/
}

// cut incomplete Codons for the using of PAML
vector<ExonCandidate*> GeneMSA::cutIncompleteCodons(vector<ExonCandidate*> orthoexon) {
    for (int i=0; i<orthoexon.size(); i++) {
        if (orthoexon[i]!= NULL) {
            if (getGFF3FrameForExon(orthoexon[i]) == 1) {
                orthoexon[i]->begin = orthoexon[i]->begin + 1;
            } else if (getGFF3FrameForExon(orthoexon[i]) == 2) {
                orthoexon[i]->begin = orthoexon[i]->begin + 2;
            } /*else if ((orthoexon[i]->type == 13) || (orthoexon[i]->type == 14) || (orthoexon[i]->type == 15) || (orthoexon[i]->type == 8)) {
                orthoexon[i]->begin = orthoexon[i]->begin + 3;
            }*/
            if ((orthoexon[i]->type == 2) || (orthoexon[i]->type == 5) || (orthoexon[i]->type == 11) || (orthoexon[i]->type == 14)) {
                orthoexon[i]->end = orthoexon[i]->end - 1;
            } else if ((orthoexon[i]->type == 3) || (orthoexon[i]->type == 6) || (orthoexon[i]->type == 10) || (orthoexon[i]->type == 13)) {
                orthoexon[i]->end = orthoexon[i]->end - 2;
            } /*else if ((orthoexon[i]->type == 7) || (orthoexon[i]->type == 0)) {
                orthoexon[i]->end = orthoexon[i]->end - 3;
            }*/
        }
    }
    return orthoexon;
}

// designed the aligned sequence of an ortholog exon candidate
string GeneMSA::getAlignedOrthoExon(AlignSeq *as_ptr, ExonCandidate* ec, string seq, vector<int> offsets, int speciesIdx) {
    if (as_ptr != NULL) {
        int alignedPosStart = getAlignedPosition(as_ptr, ec->begin + offsets[speciesIdx] + 1).first;
        int idxStart = getAlignedPosition(as_ptr, ec->begin + offsets[speciesIdx] + 1).second;
        int alignedBegin = (*(as_ptr->cmpStarts[idxStart])) + alignedPosStart;
        int alignedPosEnd = getAlignedPosition(as_ptr, ec->end + offsets[speciesIdx] + 1).first;
        int idxEnd = getAlignedPosition(as_ptr, ec->end + offsets[speciesIdx] + 1).second;
        int alignedEnd = (*(as_ptr->cmpStarts[idxEnd])) +  alignedPosEnd;
        list<block>::iterator it = upper_bound(as_ptr->sequence.begin(), as_ptr->sequence.end(), alignedBegin, compRealPos);
        list<block>::iterator it_prev = it;
        it_prev--;
        while (((*it_prev).begin + (*it_prev).length) < alignedEnd) {
            string gap = "";
            int numberGaps = (*it).previousGaps - (*it_prev).previousGaps;
            for (int j=0; j<numberGaps; j++) {
                gap += "-";
            }
            try {
                if ((*it_prev).begin != (*it).begin - ((*it).previousGaps - (*it_prev).previousGaps)  - (*it_prev).length) {
                    break;
                }
                if (gap != "") {
                    seq.insert((*it).begin - alignedBegin - numberGaps , gap);
                }
            }
            catch (...) {
                //cout<<ec->begin+offsets[speciesIdx]+1<<"   "<<ec->end+offsets[speciesIdx]+1<<"  "<<ec->type<<endl;
                cout << "sequence is too short, out of range error" << endl;
                break;
            }
            it++;
            it_prev++;
        }
        return seq;
    } else {
        return "";
    }
}

// reads the computed dN/dS ratio from a file and gives the exon candidate a score: (100*(1-dN/dS)
void GeneMSA::readOmega(string file){
    double omega;
    string omegaFilename = file;
    ifstream OmegaFile;
    OmegaFile.open(omegaFilename.c_str(), ifstream::in);
    if (!OmegaFile) {
        cerr << "Could not find the file with the dN/dS ratios " << omegaFilename << "." << endl;
        throw PropertiesError( "GeneMSA::readOmega: Could not open this file!" );
    } else {
            for (list<OrthoExon>::iterator it_oe=orthoExonsWithOmega.begin(); it_oe!=orthoExonsWithOmega.end(); it_oe++) {
                OmegaFile>>omega;
                for (int j=0; j<(*it_oe).orthoex.size(); j++) {
                    if (((*it_oe).orthoex.at(j)!=NULL) && (!OmegaFile.eof())) {
                        (*it_oe).orthoex.at(j)->score=100*(1-omega);
                    }
                }
            }
    }
    OmegaFile.close();
}

void GeneMSA::openOutputFiles(){
    string outputdirectory;  //directory for output files
    try {
        outputdirectory = Properties::getProperty("/CompPred/outdir_orthoexons");
    } catch (...) {
        outputdirectory = "";
    }
    outputdirectory = expandHome(outputdirectory); //replace "~" by "$HOME"
    exonCands_outfiles.resize(tree->species.size());
    orthoExons_outfiles.resize(tree->species.size());
    geneRanges_outfiles.resize(tree->species.size());
    omega_outfiles.resize(tree->species.size());
    for (int i=0; i<tree->species.size(); i++) {
        string file_exoncand = outputdirectory + "exonCands." + tree->species[i] + ".gff3";
        ofstream *os_ec = new ofstream(file_exoncand.c_str());
        if (os_ec!=NULL) {
            exonCands_outfiles[i]=os_ec;
            (*os_ec) << PREAMBLE << endl;
            (*os_ec) << "#\n#-----  exon candidates  -----" << endl << "#" << endl;
        }
        string file_geneRanges = outputdirectory + "geneRanges." + tree->species[i] + ".gff3";
        ofstream *os_gr = new ofstream(file_geneRanges.c_str());
        if (os_gr!=NULL) {
            geneRanges_outfiles[i]=os_gr;
            (*os_gr) << PREAMBLE << endl;
            (*os_gr) << "#\n#-----  possible gene ranges  -----" << endl << "#" << endl;
        }
        string file_orthoexon = outputdirectory + "orthoExons." + tree->species[i] + ".gff3";
        ofstream *os_oe = new ofstream(file_orthoexon.c_str());
        if (os_oe) {
            orthoExons_outfiles[i]=os_oe;
            (*os_oe) << PREAMBLE << endl;
            (*os_oe) << "#\n#----- ortholog exons  -----" << endl << "#" << endl;
        }
        string file_omega = outputdirectory + "omegaExons." + tree->species[i] + ".gff3";
        ofstream *os_omega = new ofstream(file_omega.c_str());
        if (os_omega) {
            omega_outfiles[i]=os_omega;
            (*os_omega) << PREAMBLE << endl;
            (*os_omega) << "#\n#----- exons with a dN/dS ratio smaller than one -----" << endl << "#" << endl;
        }
    }
    string paml_file = outputdirectory + "pamlfile.fa";
    ofstream *os_pf = new ofstream(paml_file.c_str());
    if (os_pf!=NULL) {
        pamlFile=os_pf;
    }
}

//writes the possible gene ranges of a species in the file 'geneRanges.speciesnames.gff3'
void GeneMSA::printGeneRanges() {
    streambuf *console = cout.rdbuf();  //save old buf
    if (!(this->exoncands.empty())) {
        for (int i=0; i<this->exoncands.size(); i++) {
            cout.rdbuf(geneRanges_outfiles[i]->rdbuf());  //redirect cout to 'geneRanges.speciesname.gff3'
            if (this->exoncands.at(i)!=NULL) {
                cout << this->getSeqID(i)<<"\tGeneRange\t"<<"exon\t"<<this->getStart(i) + 1<<"\t"<< this->getEnd(i) + 1<<"\t0\t";
                if (this->getStrand(i) == plusstrand) {
                    cout<<'+'<<"\t";
                } else {
                    cout<<'-'<<"\t";
                }
                cout<<".\t"<<"Name="<<geneRangeID<<endl;
            }
        }
        geneRangeID++;
    }
    cout.rdbuf(console); //reset to standard output again
}

//writes the exon candidates of a species of a dna segment in the file 'exonCands.species.gff3'
void GeneMSA::printExonCands(vector<int> offsets) {
    exonCandID.resize(this->exoncands.size());
    for (int j=0; j<exonCandID.size(); j++) {
        exonCandID[j]=1;
    }
    streambuf *console = cout.rdbuf();  //save old buf
    if (!(this->exoncands.empty())) {
        for (int i=0; i<this->exoncands.size(); i++) {
            cout.rdbuf(exonCands_outfiles[i]->rdbuf());  //redirect cout to 'exonCands.speciesname.gff3'
            if (this->exoncands.at(i)!=NULL) {
                cout << "# sequence:\t" << this->getName(i)<<"\t"<<this->getStart(i) + 1<< "-"<< this->getEnd(i) + 1<<"  "<<this->getEnd(i) - this->getStart(i)<<"bp"<<endl;
                for (list<ExonCandidate*>::iterator it_exonCands=this->exoncands.at(i)->begin(); it_exonCands!=this->exoncands.at(i)->end(); it_exonCands++) {
                    cout<<this->getSeqID(i)<< "\tEC\t"<<"exon\t";
                    if (this->getStrand(i) == plusstrand) {
                        cout<<(*it_exonCands)->begin + offsets[i]+1<<"\t"<<(*it_exonCands)->end + offsets[i]+1<<"\t"<<(*it_exonCands)->score<<"\t";
                        cout<<'+'<<"\t";
                    } else {
                        cout<<this->getSeqIDLength(i) - ((*it_exonCands)->end + offsets[i])<<"\t"<<this->getSeqIDLength(i) - ((*it_exonCands)->begin+ offsets[i]) <<"\t";
                        cout<<(*it_exonCands)->score<<"\t"<<'-'<<"\t";
                        //cout<<mod3(2-(exonTypeReadingFrames[(*it_exonCands)->type] - ((*it_exonCands)->end - (*it_exonCands)->begin + 1)))<<"\t";
                    }
                    cout<<getGFF3FrameForExon(*it_exonCands)<<"\t";
                    cout<<"ID="<<exonCandID[i]<<";"<<"Name="<<stateExonTypeIdentifiers[(*it_exonCands)->type]<<endl;
                    exonCandID[i]++;
                }
            } else {
                cout<<"#  no exon candidates found " << endl;
            }
        }
    } else {
        cout << "#  no exon candidates found at all" << endl;
    }
    cout.rdbuf(console); //reset to standard output again
}

//writes the orthologue exons of the different species in the files 'orthoExons.species.gff3'
void GeneMSA::printOrthoExons(RandSeqAccess *rsa, vector<int> offsets) {
    string paml;
    if (!(this->orthoExonsList.empty())) {
        try {
            Properties::assignProperty("/CompPred/paml", paml);
        }
        catch (...) {
            paml="";
        }
        for (list<OrthoExon>::iterator it_oe=orthoExonsList.begin(); it_oe!=orthoExonsList.end(); it_oe++) {
            printSingleOrthoExon(*it_oe, offsets);
            printExonsForPamlInput(rsa, *it_oe, offsets);
            if (!paml.empty()) {
                readOmega(paml);
            }
        }
        if (!paml.empty()) {
            printExonWithOmega(offsets);
        }
    }
}

//writes the orthologue exons of the different species in the files 'orthoExons.species.gff3'
void GeneMSA::printSingleOrthoExon(OrthoExon &oe, vector<int> offsets) {
    streambuf *console = cout.rdbuf();
    for (int j=0; j<oe.orthoex.size(); j++) {
        cout.rdbuf(orthoExons_outfiles[j]->rdbuf());  //direct cout to 'orthoExons.speciesname.gff3'
        if (oe.orthoex.at(j)!=NULL) {
            cout<<this->getSeqID(j)<< "\tOE1\t"<<"exon"<<"\t";
            if (this->getStrand(j) == plusstrand) {
                cout <<oe.orthoex.at(j)->begin + offsets[j]+1<<"\t"<<oe.orthoex.at(j)->end + offsets[j]+1<<"\t"<<oe.orthoex.at(j)->score<<"\t";
                cout<<'+'<<"\t";
            } else {
                cout <<this->getSeqIDLength(j) - (oe.orthoex.at(j)->end + offsets[j])<<"\t"<<this->getSeqIDLength(j) - (oe.orthoex.at(j)->begin + offsets[j])<<"\t";
                cout<<oe.orthoex.at(j)->score<<"\t"<<'-'<<"\t";
            }
            cout<<getGFF3FrameForExon(oe.orthoex.at(j)) <<"\t";
            cout<<"ID="<<oe.ID<<";Name="<<oe.ID<<";Note="<<stateExonTypeIdentifiers[oe.orthoex.at(j)->type]<<endl;
        }
    }
    cout.rdbuf(console); //reset to standard output again
}

// prints exons with an computed omega smaller than one
void GeneMSA::printExonWithOmega(vector<int> offsets) {
    streambuf *console = cout.rdbuf();
    if (!(this->orthoExonsWithOmega.empty())) {
        for (list<OrthoExon>::iterator it_oe=this->orthoExonsWithOmega.begin(); it_oe!=this->orthoExonsWithOmega.end(); it_oe++) {
            for (int j=0; j<(*it_oe).orthoex.size(); j++) {
                cout.rdbuf(omega_outfiles[j]->rdbuf()); //direct cout to 'omegaExons.speciesname.gff3'
                if (((*it_oe).orthoex.at(j)!=NULL) && ((*it_oe).orthoex.at(j)->score > 0)) {
                    cout<<this->getSeqID(j)<< "\tOO1\t"<<"exon"<<"\t";
                    if (this->getStrand(j) == plusstrand) {
                        cout <<(*it_oe).orthoex.at(j)->begin + offsets[j]+1<<"\t"<<(*it_oe).orthoex.at(j)->end + offsets[j]+1<<"\t"<<(*it_oe).orthoex.at(j)->score<<"\t";
                        cout<<'+'<<"\t";
                    } else {
                        cout <<this->getSeqIDLength(j) - ((*it_oe).orthoex.at(j)->end + offsets[j])<<"\t"<<this->getSeqIDLength(j) - ((*it_oe).orthoex.at(j)->begin + offsets[j])<<"\t";
                        cout<<(*it_oe).orthoex.at(j)->score<<"\t"<<'-'<<"\t";
                    }
                    cout<<getGFF3FrameForExon((*it_oe).orthoex.at(j)) <<"\t";
                    cout<<"ID="<<(*it_oe).ID<<";Name="<<(*it_oe).ID<<";Note="<<stateExonTypeIdentifiers[(*it_oe).orthoex.at(j)->type]<<endl;
                }
            }
        }
    }
    cout.rdbuf(console); //reset to standard output again
}

// computes the sequence for the programm paml, so that every codon in the aligned sequence has no gaps and is in reading frame 0
// maybe the method looks pedestrianly, but under specific circumstances causes PAML a segmentation fault and I try to avoid it
vector <string> GeneMSA::getSeqForPaml(AlignmentBlock *it_ab,  vector<ExonCandidate*> oe, vector<string> seq, vector<int> offsets, vector<int> speciesIdx) {
    vector<string> pamlseq;
    int comparableSeq;
    vector<int> firstBaseCodon;
    vector<int> orthoExonStart;
    vector<bool> completeCodon;
    vector<int> codonCount;
    int alignedBase = 0;
    for (vector<int>::iterator it = speciesIdx.begin(); it!=speciesIdx.end(); it++) {
        orthoExonStart.push_back(getAlignedPosition(it_ab->alignSpeciesTuple.at(*it), oe[*it]->begin + offsets[*it] + 1).first);
        firstBaseCodon.push_back(oe[*it]->begin + offsets[*it] + 1);
        completeCodon.push_back(true);
        codonCount.push_back(0);
    }
    while (alignedBase < seq[0].length()) {
        comparableSeq = 0;
        for (int i = 0; i<seq.size(); i++) {
            completeCodon[i]=true;
            for (int k=alignedBase; k < alignedBase + 3; k++) {
                if (seq.at(i)[k] == '-') {
                    completeCodon[i] = false;
                }
            }
            if ((getAlignedPosition(it_ab->alignSpeciesTuple.at(speciesIdx[i]), firstBaseCodon[i]).first - orthoExonStart[i] == alignedBase) && (completeCodon[i])) {
                comparableSeq++;
            }
        }
        if (comparableSeq > 1) {
            for (int i = 0; i < completeCodon.size(); i++) {
                if ((getAlignedPosition(it_ab->alignSpeciesTuple.at(speciesIdx[i]), firstBaseCodon[i]).first - orthoExonStart[i] == alignedBase) && (completeCodon[i])) {
                    firstBaseCodon[i] = firstBaseCodon[i] + 3;
                    codonCount[i]++;
                } else {
                    seq[i].replace(alignedBase, 3, "---");
                    if ((getAlignedPosition(it_ab->alignSpeciesTuple.at(speciesIdx[i]), firstBaseCodon[i]).first) - orthoExonStart[i] <= alignedBase ) {
                        firstBaseCodon[i] = firstBaseCodon[i] + 3;
                    }
                }
            }
        } else {
            for (int i = 0; i<completeCodon.size(); i++) {
                seq[i].replace(alignedBase, 3, "---");
                if ((getAlignedPosition(it_ab->alignSpeciesTuple.at(speciesIdx[i]), firstBaseCodon[i]).first) - orthoExonStart[i] <= alignedBase ) {
                    firstBaseCodon[i] = firstBaseCodon[i] + 3;
                }
            }
        }
        alignedBase = alignedBase + 3;
    }
    for (int i=0; i<seq.size(); i++) {
        pamlseq.push_back(seq[i]);
    }
    for (int i=0; i<seq.size(); i++) {
        if (codonCount[i] < 2) {
            pamlseq.clear();
        }
    }
    return pamlseq;
}

//writes the exons for the paml input file '
void GeneMSA::printExonsForPamlInput(RandSeqAccess *rsa, OrthoExon &oe, vector<int> offsets) {
    streambuf *console = cout.rdbuf();  //save old buf
    cout.rdbuf(pamlFile->rdbuf());  //redirect cout to 'pamlFile.fa'
    list<AlignmentBlock*>::iterator it_ab = this->alignment.begin();
    list<AlignmentBlock*>::iterator current_it_ab;
    vector<ExonCandidate*> orthoExon;
    if (!(this->orthoExonsList.empty())) {
        int noSpecies = 0;
        AnnoSequence *seqRange = NULL;
        vector<int> speciesIdx;
        int alignedOrthoExonLength=0;
        for (int j=0; j<oe.orthoex.size(); j++) {
            if (oe.orthoex[j] != NULL) {
                ExonCandidate *ec = new ExonCandidate(oe.orthoex[j]);
                orthoExon.push_back(ec);
            } else {
                orthoExon.push_back(NULL);
            }
        }
        orthoExon = cutIncompleteCodons(orthoExon);
        for (int i=0; i<orthoExon.size(); i++) {
            while (it_ab!=this->alignment.end()) {
                if (((*it_ab)->alignSpeciesTuple.at(0)->start <= orthoExon[0]->begin + offsets[0] + 1)
                        && ((*it_ab)->alignSpeciesTuple.at(0)->start + (*it_ab)->alignSpeciesTuple.at(0)->seqLen - 1 >= orthoExon[0]->end + offsets[0] + 1)) {
                    current_it_ab = it_ab;
                    break;
                } else {
                    it_ab++;
                }
            }
            if ((orthoExon.at(i) != NULL) && ((orthoExon[i]->end - orthoExon[i]->begin + 1) >= 21 )) { //sequence has to be greater than 20 bases
                seqRange = rsa->getSeq(this->getName(i), this->getSeqID(i), orthoExon[i]->begin + offsets[i], orthoExon[i]->end + offsets[i], this->getStrand(i));
                if (i == 0) {
                    alignedOrthoExonLength = getAlignedOrthoExon((*current_it_ab)->alignSpeciesTuple.at(0), orthoExon[0], seqRange->sequence, offsets, 0).length();
                }
                if ((((alignedOrthoExonLength) % 3) == 0) && (alignedOrthoExonLength) == (getAlignedOrthoExon((*current_it_ab)->alignSpeciesTuple.at(i), orthoExon[i], seqRange->sequence, offsets, i).length())) {
                    speciesIdx.push_back(i);
                    noSpecies++;
                }
            }
        }
        if (noSpecies == 2 && speciesIdx[1]==2) {
            orthoExonsWithOmega.push_back(oe);
            //printSingleOrthoExon(oe, offsets);
            vector<string> pamlSeq;
            for (vector<int>::iterator it = speciesIdx.begin(); it!=speciesIdx.end(); it++) {
                if (this->getStrand(*it) == minusstrand) {
                    seqRange = rsa->getSeq(this->getName(*it), this->getSeqID(*it), this->getSeqIDLength(*it) - (orthoExon[*it]->end + offsets[*it] + 1),
                            this->getSeqIDLength(*it) - (orthoExon[*it]->begin + offsets[*it] + 1), this->getStrand(*it));
                } else {
                    seqRange = rsa->getSeq(this->getName(*it), this->getSeqID(*it), orthoExon[*it]->begin + offsets[*it], orthoExon[*it]->end + offsets[*it], this->getStrand(*it));
                }
                string sequence = getAlignedOrthoExon((*current_it_ab)->alignSpeciesTuple.at(*it), orthoExon[(*it)], seqRange->sequence, offsets, (*it));
                if (orthoExon[*it]->type > 7) {
                    int n = sequence.length();
                    for (int j=0; j<n; j++) {
                        if ( sequence[j] != '-') {
                            sequence[j] = wcComplement(sequence[j]);
                        }
                    }
                }
                pamlSeq.push_back(sequence);
            }
            pamlSeq = getSeqForPaml((*current_it_ab), orthoExon, pamlSeq, offsets, speciesIdx);
            if (! pamlSeq.empty()) {
                cout<<noSpecies<<"  "<<alignedOrthoExonLength<<endl;
                int k=0;
                for (vector<int>::iterator it = speciesIdx.begin(); it!=speciesIdx.end(); it++) {
                    cout<<this->getName(*it)<<endl;
                    if (orthoExon[*it]->type > 7) {
                        pamlSeq[k] = reverseString(pamlSeq[k]);
                    }
                    cout<<pamlSeq[k]<<endl;
                    k++;
                }
                cout<<endl;
            }
        }
    }
    for (int j=0; j<orthoExon.size(); j++) {
        if (orthoExon[j]!=NULL) {
            delete orthoExon[j];
        }
    }
    cout.rdbuf(console); //reset to standard output again
}

void GeneMSA::closeOutputFiles(){
    for (int i=0; i<tree->species.size(); i++) {
        if (exonCands_outfiles[i]) {
            if(exonCands_outfiles[i]->is_open()) {
                exonCands_outfiles[i]->close();
                delete exonCands_outfiles[i];
            }
        }
        if (geneRanges_outfiles[i]) {
            if(geneRanges_outfiles[i]->is_open()) {
                geneRanges_outfiles[i]->close();
                delete geneRanges_outfiles[i];
            }
        }
        if (orthoExons_outfiles[i]) {
            if(orthoExons_outfiles[i]->is_open()) {
                orthoExons_outfiles[i]->close();
                delete orthoExons_outfiles[i];
            }
        }
        if (omega_outfiles[i]) {
            if(omega_outfiles[i]->is_open()) {
                omega_outfiles[i]->close();
                delete omega_outfiles[i];
            }
        }
    }
    if (pamlFile) {
        if(pamlFile->is_open()) {
            pamlFile->close();
            delete pamlFile;
        }
    }
}

/**********************************************************************
 * file:    randseqaccess.hh
 * licence: Artistic Licence, see file LICENCE.TXT or 
 *          http://www.opensource.org/licenses/artistic-license.php
 * descr.:  random acces to sequence data, e.g. get me chr1:1000-2000 from species 'human'
 * authors: Mario Stanke, Stephanie König, yuquilin
 *
 *********************************************************************/

#ifndef _RANDSEQACCESS
#define _RANDSEQACCESS

// project includes
#include "gene.hh"
#include "types.hh"

#include <map>
#include <vector>
#include <cstring>

#ifdef AMYSQL
#include <mysql++.h>
#endif

/*
 * abstract class for quick access to an arbitrary sequence segment in genomes
 * needed for comparative gene finding
 */
class RandSeqAccess {
protected:
    RandSeqAccess() {};
    virtual ~RandSeqAccess() {}
public:
    virtual AnnoSequence* getSeq(string speciesname, string chrName, int start, int end, Strand strand) =  0;
};

/*
 * Achieve random access by simply storing all genomes in memory and then retrieving the required
 * substrings when desired. This may need a lot of RAM.
 */
class MemSeqAccess : public RandSeqAccess {
public:
    MemSeqAccess();
    AnnoSequence* getSeq(string speciesname, string chrName, int start, int end, Strand strand);
  
private:
    map<string,string> filenames;
    map<string,char*> sequences;  //keys: speciesname:chrName values: dna sequence
};

/*
 * Random access to sequence segments through a database.
 * The sequences must be stored in a database.
 */
class DbSeqAccess : public RandSeqAccess {
public:
    DbSeqAccess();
    AnnoSequence* getSeq(string speciesname, string chrName, int start, int end, Strand strand);
    // the following function is for the BGI-style database
    AnnoSequence* getSeq2(string speciesname, string chrName, int start, int end, Strand strand);
#ifdef AMYSQL
    int split_dbaccess();
    void connect_db();
    template<class T>  
    AnnoSequence* getNextDBSequence(string charName, int start, int end, vector<T>& asm_query_region);
    // template<class T>
    // AnnoSequence* getDBSequenceList(string charName,int start,int end,vector<T>& asm_query_region);
    template<class T>
    int get_region_coord(int seq_region_id, int start, int end, vector<T>& asm_query_region);
    string dbaccess;
private:
    mysqlpp::Connection con;
    vector<string> db_information;
#endif // AMYSQL
};

/*
 * read an input file of format:
 * human        <TAB> /dir/to/genome/genome.fa
 * Mus musculus <TAB> /dir/to/genome/mouse.fa
 * to a map
 */
map<string,string> getFileNames (string listfile);

#endif  // _RANDSEQACCESS

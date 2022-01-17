# -*- coding: utf-8 -*-

import re

inpath = "Chuvash_Corpus_Wordlist-windows.txt" #"dict2.txt"
outpath = "chuvash-wordlist-syllabified.txt" #"chuvash-dictionary-syllabified-new.txt"

consonants = u"ҫвйклмнпрстхчш"
foreign_consonants = u"бдгфцщжз"
consonant_modifier = u"ь"
vowels = u"аӑыуеӗиӳэяю"
palatal_vowels = u"яюе"
foreign_vowels = u"оё"
other_symbols = u"-"

consonants_with_modifier = list(consonants) + [c + consonant_modifier for c in consonants]

possible_consonants = "(?:%s)" % "|".join(consonants_with_modifier)

full_vowels = u"аыуеиӳэяю"
reduced_vowels = u"ӑӗ"

def create_partitions(inlist, Lenv, Renv):
    #Goes through each of the strings in inlist and partititions them into substrings
    #according to whether the left environment at the partition matches Lenv and
    #the right environment matches Renv, which are regular expressions.
    
    #initialize new list
    newlist = list()
    
    for s in inlist:
        
        #check if the environments exist in this segment; if not, put the whole segment in the list
        if re.search(Lenv + Renv, s):
        
            #iterate through possible partition locations
            for i in range(1,len(s)):
                
                #make possible partition
                Lpart = s[:i]
                Rpart = s[i:]
                
                #check environments
                if re.search("%s$" % Lenv, Lpart) and re.search("^%s" % Renv, Rpart):
                    
                    #make partition
                    newlist.append(Lpart)
                    
                    #recurse to further explore the right part
                    newlist += create_partitions([Rpart], Lenv, Renv)
                    
                    #break so as not to double up
                    break
                
        else:
            
            newlist.append(s)
    
    #return the list
    return newlist

with open(inpath, "rb") as infile:
    with open(outpath, "wb") as outfile:   
        
        for word in infile:            
            
            word = word.decode('utf-8')
            
            word = word.lower()
            
            word = word.replace("\n","").replace("\r","")
            
            
            if not (word.startswith("-") or re.search(u"[%s]" % (foreign_vowels + foreign_consonants), word)):
                
                #replace - with .
                word = word.replace("-",".").replace("_",".")
                
                #put word in a list to enable partitioning using the custom function
                word = word.split(".")
                
                #put partitions between vowels
                word = create_partitions(word, u"[%s]" % vowels, u"[%s]" % vowels)
                
                #put partitions between consonant modifiers and palatal vowels
                word = create_partitions(word, consonant_modifier, u"[%s]" % palatal_vowels)
                
                #put partitions between two consonants followed by a third consonant
                word = create_partitions(word, u"%s{2}" % possible_consonants, possible_consonants)
                
                #put partitions between a consonant and a consonant followed by a vowel
                word = create_partitions(word, possible_consonants, u"%s[%s]" % (possible_consonants, vowels))
                
                #put partitions between a vowel and a consonant followed by a vowel
                word = create_partitions(word, u"[%s]" % vowels, u"%s[%s]" % (possible_consonants, vowels))
                
                #NOW DO STRESS
                
                #stress falls on the rightmost syllable containing a full vowel (if such a syllable exists)
                #otherwise, stress falls on the first syllable
                
                #start from rightmost syllable
                stressed_flag = False
                for i in range(len(word)-1,0,-1):
                    syll = word[i]
                    if re.search(u"[%s]" % full_vowels, syll):
                        syll = "'" + syll
                        word[i] = syll
                        stressed_flag = True
                        break
                
                #otherwise condition
                if not stressed_flag:
                    word[0] = "'" + word[0]
                
                #join syllables with dots
                word = '.'.join(word)
                
                #write word to file
                outfile.write(word.encode('utf-8') + "\n")
                
            else:
                
                outfile.write("\n")
                
        
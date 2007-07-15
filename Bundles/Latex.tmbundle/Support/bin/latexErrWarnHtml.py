#!/usr/bin/env python

import sys
import re
from os.path import basename
import os
from struct import *

def percent_escape(str):
	return re.sub('[\x80-\xff /&]', lambda x: '%%%02X' % unpack('B', x.group(0))[0], str)

def make_link(file, line):
	return 'txmt://open?url=file:%2F%2F' + percent_escape(file) + '&line=' + line

#in a multifile latex document the current document will come after a left paren
newFilePat = re.compile('.*\((\.\/.*\.tex)')
warnPat = re.compile('LaTeX Warning.*?input line (\d+).$')
errPat = re.compile('^([\.\/\w\x7f-\xff]+\.tex):(\d+):.*')
incPat = re.compile('.*\<use (.*?)\>');
miscWarnPat = re.compile('LaTeX Warning:.*')

verbose = False
if len(sys.argv) > 1 and sys.argv[1] == '-v':
    verbose = True
    sys.argv[1:] = sys.argv[2:]
if len(sys.argv) == 3:
    texCommand = sys.argv[1]
    fileName = sys.argv[2]
else:
    sys.stderr.write("Usage: "+argv[0]+" [-v] tex-command file.tex")
    sys.exit(255)

tex = os.popen(texCommand+" "+fileName)

numWarns = 0
numErrs = 0
numRuns = 0
inbibidx = False
isFatal = False

print '<pre>'
line = tex.readline()
while line:
    line = line.rstrip("\n")
    # print out first line
    if re.match('^This is',line):
        print line[:-1]
    if re.match('^Document Class',line):
        print line[:-1]
    m = newFilePat.match(line)
    if m:
        currentFile = m.group(1)
        print "<h3>Typesetting: " + currentFile + "</h3>"
    inf = incPat.match(line)
    if inf:
        print "    Including: " + inf.group(1)
    if re.match('^Output written',line):
        print line[:-1]
    if re.match('Running makeindex',line):
        print '<div class="mkindex">'        
        print '<h3>' + line[:-1] + '</h3>'
        sys.stdin.readline()
        inbibidx = True
    
    if re.match('\! LaTeX Error:', line):
        print '<div class="error">'
        print line
        print '</div>'
        numErrs = numErrs + 1
    if re.match('^Error: pdflatex', line):
        numErrs = numErrs + 1
        print '<div class="error">'
        print line
        line = sys.stdin.readline()
        if line and re.match('^ ==> Fatal error occurred', line):
            print line.rstrip("\n")
            print '</div>'
            isFatal = True
        else:
            print '</div>'
            continue

    le = re.match('([^:]*):(\d+): LaTeX Error:(.*)',line)
    if le:
        print '<div class="warning">'
        latexErrorMsg = '<a class="warning" href="' + make_link(os.getcwd()+'/'+le.group(1),le.group(2)) +  '">' + le.group(1)+":"+le.group(2) + '</a> '+le.group(3)
        line = sys.stdin.readline()
        while len(line) > 1:
            latexErrorMsg = latexErrorMsg+line
            line = sys.stdin.readline()
        print latexErrorMsg+'</div>'
        numWarns = numWarns + 1
    
    es = re.match('([^:]*):(\d+): Emergency stop',line)
    if es:
        print '<div class="error">'
        print '<a class="error" href="' + make_link(os.getcwd()+'/'+es.group(1),es.group(2)) +  '">' + es.group(1) + '</a>'
        print 'See the log file for details'
        print '</div>'
        numErrs = numErrs + 1

    ts = re.match('Transcript written on (.*).$',line)
    if ts:
        print '<div class="error">'
        print '<a class="error" href="' + make_link(os.getcwd()+'/'+ts.group(1),'1') +  '">' + ts.group(1) + '</a>'
        print '</div>'
        
    if re.match('Running bibtex',line):
        print '<div class="bibtex">'
        print '<h3>' + line[:-1] + '</h3>'
        sys.stdin.readline()
        inbibidx = True
        
    if re.match('---',line) and inbibidx:
        print '</div>'
        inbibidx = False

    if re.match("Warning--I didn't find a database entry",line):
        print line
        
    if re.match('Run number',line):
        print '<hr />'
        numWarns = 0
        numErrs = 0
        numRuns = numRuns + 1
        print '<hr />'
        
    w = warnPat.match(line)
    e = errPat.match(line)
    me = miscWarnPat.match(line)
    
    # elif we detect a warning message add the current file to the warning plus a tag
    # to make it easy to pick out the line as an error line in TextMate.
    # Do the same thing for error messages.
    if w:
        print '<a class="warning" href="' + make_link(os.getcwd()+currentFile[1:], w.group(1)) + '">'+line+"</a>"
        numWarns = numWarns+1
    elif e:
        numErrs = numErrs+1
        nextLine = sys.stdin.readline()
        print '<a class="error" href="' + make_link(os.getcwd()+e.group(1)[1:], e.group(2)) + '">'+line[:-1]+nextLine+"</a>"        
    elif me:
        numWarns = numWarns + 1
        sys.stdout.write('<p class="warning">' + line[:-1] + '</p>')
    else:
        if verbose:
            print line[:-1]
    line = tex.readline()
texStatus = tex.close()
eCode = 0
if texStatus != None or numWarns > 0 or numErrs > 0:
    print "Found " + str(numErrs) + " errors, and " + str(numWarns) + " warnings in " + str(numRuns) + " runs"
    if texStatus != None:
        signal = (texStatus & 255)
        returnCode = texStatus >> 8
        if signal != 0:
            print "TeX killed by signal " + str(signal)
        else:
            print "TeX exited with error code " + str(returnCode)

    if isFatal:
        eCode = 3
    elif numErrs > 0 or texStatus != None:
        eCode = 2
    else:
        eCode = 1
# else:
#     print "Success"

print '</pre>'
sys.exit(eCode)

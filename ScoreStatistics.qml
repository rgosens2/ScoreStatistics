//=============================================================================
//  MuseScore
//
//  Score Statistics Plugin
//
//  Collects and lists statistics about the current score
//
//  Version 1.0
//
//  Copyright (C) 2021 rgos
//=============================================================================
import QtQuick 2.0
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.3
import QtQuick.Layouts 1.1
import QtQuick.Window 2.2
import Qt.labs.settings 1.0
import QtQuick.Dialogs 1.1

import FileIO 3.0

import MuseScore 3.0


MuseScore {
    menuPath: "Plugins.Score Statistics"
    version: "3.0"
    description: qsTr("Collects and lists statistics about the current score")
    pluginType: "dialog"
    requiresScore: true
    
    
    /////////////////
    // JS global var for access in QML
    // Alas QML does not use the variable that JS has changed
    // TODO: make QML access a JS var
    // YESS: works now!!! Accessible from QML and JS can manipulate the var    
    property var notelist: ""
    property var msg: ""
    
    property var chordCount: 0
    property var noteCount: 0
    property var restCount: 0 
    
    property var noteLength: 0
    property var restLength: 0
            
    //property var noteLengthC: 0 
    //property var noteLengthCis:  0
    
    property var measureCount: 0
    property var staffCount: 0
    property var partCount: 0
    property var pageCount: 0

    
    /////////////////
    // For Score Statistics
    property var scorestats: ""
    
    // Arrays containing the number of occurrences and the total duration of each pitch
    property var g_numOfPitches: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var g_lenOfPitches: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    // Arrays containing the occurrences of each note duration and of each rest duration    
    property var g_noteLengths: []
    property var g_restLengths: []
    
    // Array with the note names used for output
    property var g_noteNames: ["C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B"]

    // Array with duration of each unit
    property var g_nDurations: [0, 30, 60, 120, 240, 480, 960, 1920]
    property var g_szDurNames: ["-", "1/64", "1/32", "1/16", "Quaver", "Crochet", "Half note", "Whole note"]

    // NOTE: the original Score Statistics for MuseScore 1.0 had Crochet (1/4) and Quaver (1/8) mixed up.
    // We have corrected it but we'll leave in the British terms for sentimental reasons.

    
    
    //function saveNotelist() {
    function saveScorestats() {
        // Create stats
        createScoreStats();
        
        var rc = outfile.write(scorestats);
        if (rc) {
              msg = "Score statistics saved in " + outfile.source;
              console.log(msg);
              //txtSaved.text = msg;
              return [true, outfile.source];
              // Cannot show message box from JS
              //alert("Alert text");
              //if (Qt.platform.os=="windows") {
              //    proc.start("notepad " + outfile.source); // Windows
              //}
        } else {
              msg = "Could not write score statistics to " + outfile.source;
              console.log(msg);
              //txtSaved.text = msg;
              return [false, outfile.source];
        }
    }
    
    
    function createScoreStats() {
        // TEST: create text for score stats .csv
        //var scorestats = "";
        scorestats = "";
        // get user-requested unit
        var unit = g_nDurations[beatBase2.currentIndex + 1];
        console.log("BB: " + beatBase2.currentIndex);
        // output title and lenght unit
        // text += ("\"Statistics for '" + curScore.name + "'\"\n");
        scorestats += ("\"Lenght unit:\",\"" +
                g_szDurNames[beatBase2.currentIndex + 1] + "\"\n");
        // output summary
        scorestats += ("\"Parts:\"," + partCount + "\n");
        scorestats += ("\"Pages:\"," + pageCount + "\n");
        scorestats += ("\"Bars:\","  + measureCount  + "\n");
    
        // output pitch occurrences and durations
        for(idx=0; idx < 12; idx++)
            scorestats += ("\"" + g_noteNames[idx] + "\"," + g_numOfPitches[idx] + "," + (g_lenOfPitches[idx]/unit).toPrecision(6) + "\n");
    
        // output totals
        scorestats += ("\"Total number of notes:\","   + noteCount + "\n");
        scorestats += ("\"Total duration of notes:\"," + (noteLength/unit).toPrecision(6) + "\n");
        scorestats += ("\"Total number of rests:\","   + restCount + "\n");
        scorestats += ("\"Total duration of rests:\"," + (restLength/unit).toPrecision(6) + "\n");
    
        // output summary of note and rest length distribution
        scorestats += ("\"Occurences of note lengths\"\n");
        for(idx in g_noteLengths)
            scorestats += ("" + (idx/unit).toPrecision(6) + "," + g_noteLengths[idx] + "\n");
        scorestats += ("\"Occurences of rest lengths\"\n");
        for(idx in g_restLengths)
            scorestats += ("" + (idx/unit).toPrecision(6) + "," + g_restLengths[idx] + "\n");
        /////////////////////
    }
    
    
    /////////////////
    // TODO: gaat fout met opmaat: er wordt tweemaal measure 1 geteld
    // NOTE: let op dat de maatnummering bij een opmaat/pickup telt vanaf de eerste hele maat maar dat Ms
    // zelf de opmaat als nummer 1 telt, maar dat was hier niet het issue. Hij deed iets met noOffset en irregular
    function buildMeasureMap(score) {
        var map = {};
        var no = 1;
        var cursor = score.newCursor();
        cursor.rewind(Cursor.SCORE_START);
        while (cursor.measure) {
            var m = cursor.measure;
            var tick = m.firstSegment.tick;
            var tsD = m.timesigActual.denominator;
            var tsN = m.timesigActual.numerator;
            var ticksB = division * 4.0 / tsD;
            var ticksM = ticksB * tsN;
            //no += m.noOffset;         
            var cur = {
                "tick": tick,
                "tsD": tsD,
                "tsN": tsN,
                "ticksB": ticksB,
                "ticksM": ticksM,
                "past" : (tick + ticksM),
                "no": no
            };
            map[cur.tick] = cur;
            console.log(tsN + "/" + tsD + " measure " + no +
                " at tick " + cur.tick + " length " + ticksM);
            //if (!m.irregular)
            //  ++no;
            no++;
            cursor.nextMeasure();
        }
        return map;
    }
    
    function showPos(cursor, measureMap) {
        var t = cursor.segment.tick;
        var m = measureMap[cursor.measure.firstSegment.tick];
        var b = "?";
        if (m && t >= m.tick && t < m.past) {
            b = 1 + (t - m.tick) / m.ticksB;
        }
    
        return "St: " + (cursor.staffIdx + 1) +
            " Vc: " + (cursor.voice + 1) +
            " Ms: " + m.no + " Bt: " + b;
    }       
    ////////////////////


    
    onRun: {
        if (!curScore) {
            console.log(qsTranslate("QMessageBox", "No score open.\nThis plugin requires an open score to run.\n"));
            Qt.quit();
        }
        
        
        // TODO: make accessible from QML
        //var notelist = '';
        
        
        // TEST:
        //saveFileDialog.folder = ((Qt.platform.os=="windows")? "file:///" : "file://") + curScore.filePath;
        //saveFileDialog.open();
        
        
        // RG: why do we have to start at -3 to get the correct number of measures?
        // It is because we loop through segments and we had 4 notes in the first measure
        // It only works when measures are empty.
        var internalMeasureNumber = 1; //we will use this to track the current measure number
        //var currentMeasure = null; //we use this to keep a reference to the actual measure, so we can know when it changes
        
        //var chordCount = 0;
        //var noteCount = 0;
        //var restCount = 0;      
        
        //var noteCountC = 0;        
        //var noteLengthC = 0;
        //var noteCountCis = 0;        
        //var noteLengthCis = 0;
        
        ///////////
        // Arrays containing the number of occurrences and the total duration of each pitch
        //var g_numOfPitches = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        //var g_lenOfPitches = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        //
        // Arrays containing the occurrences of each note duration and of each rest duration
        //var g_noteLengths = [];
        //var g_restLengths = [];
        ///////////
        
        
        //var measureCount = 0;
        measureCount = curScore.nmeasures;
        
        //var staffCount = 0;
        staffCount = curScore.nstaves;
        
        //var partCount = 0;
        partCount = curScore.parts.length;
        
        //var pageCount = 0;
        pageCount = curScore.npages;

        //get a cursor to be able to run over the score
        var cursor = curScore.newCursor();
        cursor.rewind(0);
        cursor.voice = 0;
        cursor.staffIdx = 0;
        
        
        var measure = 1;
        var beat = 1;
        
        //var tickCount = 0;
        
        
        
        // find ticks for measure 2
        var m2 = cursor.measure.nextMeasure.firstSegment.tick;
        console.log('m2: ' + m2); 
        
        var nextM = m2;
        
        
        var measureMap = buildMeasureMap(curScore);
    
        
          
            
        // TODO: loop through all staves
        // NOTE: when staves are made invisible they are still counted: check for visibility
        
        
        // HELL: we can only loop through 2 staves. Why?
        // Works OK with Ligeti but not our Test1 file.
        // staffCount is OK.
        // If we recreate the cursor it will work.
        
        
        
        // loop through all staves
        for (var s = 0; s < staffCount; s++) {
            cursor = curScore.newCursor(); // recreate to be sure
            cursor.rewind(0);
            cursor.staffIdx = s;
            
            // restart
            //measure = 1;      
            //nextM = m2;
            
            // loop through all voices
            for (var v = 0; v < 4; v++) {
                cursor.rewind(0);
                cursor.voice = v;               
                
                // restart
                //measure   = 1;        
                //nextM = m2;
                
                // loop through all segments
                while (cursor.segment) {
                    // TODO: count correctly when measures are full
                    // SHIT: why are we getting 4 different pointers to the first measure?
                    // This causes the 3 times overcount of measures when there are 4 chords in the first measure
                    //console.log(cursor.measure);
                    // We should just use:
                    //measureCount = curScore.nmeasures;
                    
                    // NONO:
        //            if (cursor.measure != currentMeasure) {
        //                 //we moved into a new measure
        //                 // NONO: will not work because cursor.measure returns a different pointer for every chord
        //                 // even when in the same measure!!! Sucks!!!
        //                 internalMeasureNumber++;
        //                 currentMeasure = cursor.measure;
        //                 
        //                 // LOOK: how nasty
        //                 console.log(cursor.measure);
        //                 
        //                 // TODO: find a way to count measures correctly in a loop
        //            }
        
                    
                    // TODO: list all notes as in the Musescore status bar:
                    // Note; Pitch: C6; Duration: Quarter; Voice: 1; Measure: 1; Beat: 1; Staff: 1 (Piano)
                  
                  
                    // TODO: get instrument name
                    // MS uses Part.longName in the status bar
                    //console.log(cursor.part.longName);
                    // This works but how do we find out how many staves a part has?
                    // See Staff.part:
                    // Ms::PluginAPI::Part  part
                    // Part which this staff belongs to
                    //
                    // So like this: Score->Stave->Part
                    //console.log(curScore.parts[0].longName); // works
                    //console.log(curScore.staves[s].part.longName); // why not?
                    //console.log(curScore.title);
                    // staves is niet bereikbaar, fout in API
                    // Yep: https://musescore.org/en/node/317368
                    //console.log(curScore.parts.length); // OK
                    //console.log(curScore.staves.length); // cannot read property of undefined
                    // YESS: can get staff via element
                    // cursor.element.staff.part.longName
                    
                    // TEST: find actual time sig
                    // YESS: need cursor.measure
                    console.log(cursor.measure.timesigActual.numerator + '/' + cursor.measure.timesigActual.denominator);
                    
                    // TEST:
                    var m = cursor.measure; 
                    var tsD = m.timesigActual.denominator;
                    var tsN = m.timesigActual.numerator;
                    var ticksB = division * 4.0 / tsD;
                    var ticksM = ticksB * tsN;
                   
                    console.log(ticksB + '/' + ticksM);
                    
                  
                    
                  
                    
                    // we are looping through segments, can we find the proper measure and beat without
                    // first constructing a measure map?
                    //var t = cursor.tick;
                    
                    
                    // YESS: it can be done like this
                    // TODO: find a way to find the initial nextM
                    // DONE
                    // SHIT: things go wrong with voice 2 with empty measures because of firstSegment
                    // skipping totally empty measures
                    // NOTE: dit moet dus ook fout gaan in count-note-beats.qml maar daar is het niet
                    // erg want het measure nummer is niet nodig, alleen de beat. En dat gaat goed.
                    // TODO: hoe kunnen we juist blijven tellen bij maten die helemaal leeg zijn?
                    // Hebben we toch een measure map nodig die is gemaakt met voice 1 die nooit helemaal
                    // lege maten heeft?
                    // Is waarschijnlijk toch het handigst: je kunt dan voor elk segment met zijn tick
                    // opzoeken in welke maat het zich bevindt.
                    // Old method
                    var t = cursor.segment.tick;
                    console.log(t);
                    
                    
                    // Use measure map
                    var mm = measureMap[cursor.measure.firstSegment.tick];
                    measure = mm.no;
                    
                    beat = 1 + (t - mm.tick) / mm.ticksB;
                    
                    
                    // TODO: round beat to 5 decimals for triplets
                    beat = +beat.toFixed(5);
                    
                    
                    
                    // TEST:
                    console.log( showPos(cursor, measureMap) );
                    
                    
                    // TEST: count rests
                    if (cursor.element && cursor.element.type == Element.REST) {
                        restCount++;
                        restLength += cursor.element.duration.ticks;
                        
                        // TEST:
                        var length = cursor.element.duration.ticks;
                        if (g_restLengths[length] == undefined)
                            g_restLengths[length] = 1;
                        else
                            g_restLengths[length]++;
                    }   
                        
                        
                    
                    // TEST: count notes
                    if (cursor.element && cursor.element.type == Element.CHORD) {
                        chordCount++;
                        //noteCount += cursor.element.notes.length;
                        
                        //console.log('Chords: ' + chordCount);
                        //console.log('Notes: ' + noteCount);
                        
                        // TEST: print measure number
                        //console.log( 'Measure: ' + ( Math.floor(cursor.tick/1920) + 1) );
                        //console.log( 'Beat: ' + (((cursor.tick/480)%4) + 1) );
                        
                        // TODO: 1920 for measure and 480 for beat are for quarter note
                        // Make universal and make sure it works with unregular measures
                        // and pickup measures
                        // A pickup measure of 1 quarter is measure 1, beat 1 so must use
                        // Actual measure duration (timesigActual)
                        // For every measure we are in we need to know the actual time signature
                        // Use cursor.element.timesigActual
                        //var measure = Math.floor(cursor.tick/1920) + 1;
                        //var beat = (cursor.tick/480)%4 + 1;
                        
                        
                        
                        
                        // get note duration
                        var duration = cursor.element.duration.str;
                   
                        
                        // TODO: get all the notes in a chord
                        // DONE
                        //console.log(cursor.element.notes.CountFunction);
                        //console.log( cursor.element.notes.length );
                        
                        // TODO: loop through all notes in a chord and count the pitches
                        for (var i = 0; i < cursor.element.notes.length; i++) {
                            noteCount++;
                            noteLength += cursor.element.duration.ticks;
                            
                            
                            // TEST:
                            var length = cursor.element.duration.ticks;
                            if (g_noteLengths[length] == undefined)
                                g_noteLengths[length] = 1;
                            else
                                g_noteLengths[length]++;                    
                                
                            
                            
                            
//                            // TEST:
//                            switch (cursor.element.notes[i].tpc) {
//                                case 14:
//                                case 26:
//                                case 2:
//                                    noteCountC++; 
//                                    noteLengthC += cursor.element.duration.ticks;                           
//                                    // TEST: print note and length and voice
//                                    //console.log('Voice: ' + (v+1) + ' Note: C' + ' ' + cursor.element.duration.str); 
//                                    //console.log('Note; Pitch: C; Duration: ' + duration + '; Voice: ' + (v+1) + '; Measure: ' + measure +'; Beat: ' + beat + '; Staff 1');
//                                    break;
//                                case 21:
//                                case 33:
//                                case 9:
//                                    noteCountCis++; 
//                                    noteLengthCis += cursor.element.duration.ticks;
//                                    // TEST: print note and length and voice
//                                    //console.log('Voice: ' + (v+1) + ' Note: C#/Db' + ' ' + cursor.element.duration.str); 
//                                    //console.log('Note; Pitch: C#/Db; Duration: ' + duration + '; Voice: ' + (v+1) + '; Measure: ' + measure +'; Beat: ' + beat + '; Staff 1');
//                                    break;
//                            }
                            
                            var pitch = cursor.element.notes[i].pitch;
                            var tpc   = cursor.element.notes[i].tpc;
                            
                            var octave = Math.floor(pitch/12)-1;
                            var notename = '';
                            
                            
                            // TEST:
                            g_numOfPitches[pitch%12]++;
                            g_lenOfPitches[pitch%12] += length;
                            
                            
                            
                            // For note list
                            switch (pitch%12) {
                                case 0:
                                    if (tpc == 26) notename ='B#';
                                    if (tpc == 14) notename ='C';
                                    if (tpc == 2 ) notename ='Dbb';
                                    break;
                                case 1:
                                    if (tpc == 33) notename ='B##';
                                    if (tpc == 21) notename ='C#';
                                    if (tpc == 9 ) notename ='Db';
                                    break;
                                case 2:
                                    if (tpc == 28) notename ='C##';
                                    if (tpc == 16) notename ='D';
                                    if (tpc == 4 ) notename ='Ebb';
                                    break;
                                case 3:
                                    if (tpc == 23) notename ='D#';
                                    if (tpc == 11) notename ='Eb';
                                    if (tpc == -1) notename ='Fbb';
                                    break;
                                case 4:
                                    if (tpc == 30) notename ='D##';
                                    if (tpc == 18) notename ='E';
                                    if (tpc == 6 ) notename ='Fb';
                                    break;
                                case 5:
                                    if (tpc == 25) notename ='E#';
                                    if (tpc == 13) notename ='F';
                                    if (tpc == 1 ) notename ='Gbb';
                                    break;
                                case 6:
                                    if (tpc == 32) notename ='E##';
                                    if (tpc == 20) notename ='F#';
                                    if (tpc == 8 ) notename ='Gb';
                                    break;
                                case 7:
                                    if (tpc == 27) notename ='F##';
                                    if (tpc == 15) notename ='G';
                                    if (tpc == 3 ) notename ='Abb';
                                    break;
                                case 8:
                                    if (tpc == 22) notename ='G#';
                                    //
                                    if (tpc == 10) notename ='Ab';
                                    break;
                                case 9:
                                    if (tpc == 29) notename ='G##';
                                    if (tpc == 17) notename ='A';
                                    if (tpc == 5 ) notename ='Bbb';
                                    break;
                                case 10:
                                    if (tpc == 24) notename ='A#';
                                    if (tpc == 12) notename ='Bb';
                                    if (tpc == 0 ) notename ='Cbb';
                                    break;
                                case 11:
                                    if (tpc == 31) notename ='A##';
                                    if (tpc == 19) notename ='B';
                                    if (tpc == 7 ) notename ='Cb';
                                    break;
                            }
                            
                            
/*
pitch   tpc name    tpc name    tpc name
11  31  A## 19  B   7   Cb
10  24  A#  12  Bb  0   Cbb
9   29  G## 17  A   5   Bbb
8   22  G#          10  Ab
7   27  F## 15  G   3   Abb
6   32  E## 20  F#  8   Gb
5   25  E#  13  F   1   Gbb
4   30  D## 18  E   6   Fb
3   23  D#  11  Eb  -1  Fbb
2   28  C## 16  D   4   Ebb
1   33  B## 21  C#  9   Db
0   26  B#  14  C   2   Dbb 
*/                      
                            
                        
                            // get part
                            //console.log(cursor.element.staff.part.longName);
                            var part = cursor.element.staff.part.longName;
    
                            // TODO: print correct notename using tpc and pitch
                            // DONE                 
                            //console.log(notename + octave);
                            console.log('Note; Pitch: ' + notename + octave + '; Duration: ' + duration + '; Voice: ' + (v+1) + '; Measure: ' + measure + '; Beat: ' + beat + '; Staff: ' + (s+1) + ' (' + part + ')');
    
    
                            tV.append({ number: noteCount,
                                        element: 'Note',
                                        pitch: notename + octave,
                                        duration: duration,
                                        voice: (v+1),
                                        measure: measure,
                                        beat: beat,
                                        staff: (s+1),
                                        part: part});
                                        
                            notelist += (noteCount + '; Note; Pitch: ' + notename + octave + '; Duration: ' + duration + '; Voice: ' + (v+1) + '; Measure: ' + measure + '; Beat: ' + beat + '; Staff: ' + (s+1) + ' (' + part + ')');
                            notelist += '\n';
                        
                            
                        } // End note loop
                        
        
                        // TEST: get duration of note
                        //console.log('Length: ' + cursor.element.duration.ticks); 
                        
                        //console.log(noteCount);
                        
                    } // End chord loop
                    
                    // step to next segment
                    cursor.next();
                    
                } // End while loop segments
                
                // rewind for next voice (will do at begin)
                //cursor.rewind(0);
                
            } // End voice loop
            
            // rewind cursor for next staff (not necessary)
            //cursor.rewind(0);
            
        } // End staff loop
        
        
        
        // TEST: Count number of measures with cursor loop
        // Why does it no longer work since we added voice count?
        // DONE: it works again with a new cursor. Why can't we use the old one?
        var cursor2 = curScore.newCursor();
        cursor2.rewind(0);
        cursor2.voice = 0;
        cursor2.staffIdx = 0;
        while ( cursor2.nextMeasure() ) {
            internalMeasureNumber++;
            //console.log('M');             
        }
        
        
        // NONO: this will overcount when measures contain notes
        // DONE: its correct now
        console.log('Measures: ' + internalMeasureNumber);
        //Qt.quit();
        
        
        // TODO: get from combo box at startup via ini file
        var unit = 480;
        
        
        //helloQml.text = "QQQ";
        // NOTE: the . eats the following space
        helloQml1.text = 'Num.&nbsp;bars:&nbsp;&nbsp;' + measureCount;
        helloQml2.text = 'Num.&nbsp;notes:&nbsp;&nbsp;' + noteCount;        
        //helloQml3.text = 'Num.&nbsp;staves:&nbsp;&nbsp;' + staffCount;
        helloQml3.text = 'Duration of notes:&nbsp;&nbsp;' + (noteLength/unit).toPrecision(6);
        
        helloQml4.text = 'Num.&nbsp;parts:&nbsp;&nbsp;' + partCount;
        helloQml5.text = 'Num.&nbsp;pages:&nbsp;&nbsp;' + pageCount;       
        
        helloQml6.text = 'Num.&nbsp;rests:&nbsp;&nbsp;' + restCount;
        helloQml7.text = 'Duration of rests:&nbsp;&nbsp;' + (restLength/unit).toPrecision(6);
        
        
        
        var idx = 0;
        var text = "";
        
        // list note occurences
        //helloQmlC.text =   noteCountC;
        //helloQmlCis.text = noteCountCis;      
        
        // list note occurences
        for (idx=0; idx < 12; idx++) {
            eval("txtOcc"+idx).text = g_numOfPitches[idx];
        }
        
        
        // list note lengths
        //helloQmlCLength.text =   (noteLengthC/unit).toPrecision(6);
        //helloQmlCisLength.text = (noteLengthCis/unit).toPrecision(6);      
        
        // list note lengths
        for (idx=0; idx < 12; idx++) {
            eval("txtLen"+idx).text = (g_lenOfPitches[idx]/unit).toPrecision(6);
        }
        
        
        
        // list occurences of note lengths
        text = "";        
        for (idx in g_noteLengths) {    
            text += "" + (idx/unit).toPrecision(6) + ":\t" + g_noteLengths[idx] + "\n";
        }
        myTextBox1.text = text;
        
        
        // list occurences of rest lengths
        text = "";
        for (idx in g_restLengths) {    
            text += "" + (idx/unit).toPrecision(6) + ":\t" + g_restLengths[idx] + "\n";
        }
        myTextBox2.text = text;
        
        
        
        
        
        // TEST: fill table YESS
//        tV.append({title: "some value",
//                           author: "Another value",
//                           year: "One more value",
//                           revision: "uno mas"});

        // Write note list to home dir
        // TODO: we actually want to do this from QML with a button but cannot access the JS variable
        //var rc = outfile.write(notelist);

        
    }
    
    
    ////////////////////////////////////////////////////
    FileIO {
        id: outfile
        source: homePath() + "/" + curScore.scoreName + "_scorestats.csv"
        onError: console.log(msg)
    }
    
    
    width:  500
    height: 600
    
    Settings {
        id: settings
        category: "Plugin-ScoreStatistics"
        property alias bb: beatBase.currentIndex
        property alias bb2: beatBase2.currentIndex
    }
    
    
    // TEST:
//    FileDialog {
//        id: saveFileDialog
//        selectExisting: false
//        nameFilters: ["Text files (*.txt)", "All files (*)"]
//        onAccepted: saveFile(saveFileDialog.fileUrl, textEdit.text)
//        visible: true
//    }
    
 
    
    Rectangle {
        //id: myRect
        //color: "blue"
        //anchors.fill: parent
        //anchors.margins: 10
   
        
       Text {
            id: txt1
            //anchors.centerIn: parent
            x: 20
            y: 20
            text: qsTr("Unit of measure for lengths:")
        }
        
        ComboBox {
              id: beatBase
              width: 80             
              x: 196
              y: 15
              model: ListModel {
                    id: beatBaseList
                    //mult is a tempo-multiplier compared to a crotchet
                    ListElement { text: '64th';    unit: 30   } 
                    ListElement { text: '32th';    unit: 60   } 
                    ListElement { text: '16th';    unit: 120  } 
                    ListElement { text: '8th';     unit: 240  }  
                    ListElement { text: 'Quarter'; unit: 480  } // 1/4
                    ListElement { text: 'Half';    unit: 960  }
                    ListElement { text: 'Whole';   unit: 1920 }
              }
              currentIndex: 4
              //implicitHeight: 42
              style: ComboBoxStyle {
                    //textColor: '#000000'
                    //selectedTextColor: '#000000'
                    //font.family: 'Leland'
                    //font.pointSize: 18
                    padding.top: 5
                    padding.bottom: 5
              }
              onCurrentIndexChanged: { // update the value fields to match the new beatBase
                    var unit = beatBase.model.get(currentIndex).unit;
                    
                    // relist lengths
                    //helloQml3.text = 'Duration of notes:&nbsp;&nbsp;' + (noteLength/unit).toPrecision(6);
                    //helloQml7.text = 'Duration of rests:&nbsp;&nbsp;' + (restLength/unit).toPrecision(6);
        
                    //helloQmlCLength.text =   (noteLengthC/unit).toPrecision(6);
                    //helloQmlCisLength.text = (noteLengthCis/unit).toPrecision(6);
                    
                    var idx = 0;
                    var text = "";
                    
                    // relist note lengths
                    for (idx=0; idx < 12; idx++) {
                        eval("txtLen"+idx).text = (g_lenOfPitches[idx]/unit).toPrecision(6);
                    }
                    
                    // relist occurences of note lengths
                    text = "";                  
                    for (idx in g_noteLengths) {    
                        text += "" + (idx/unit).toPrecision(6) + ":\t" + g_noteLengths[idx] + "\n";
                    }
                    myTextBox1.text = text;
                    
                    // relist occurences of rest lengths
                    text = "";
                    for (idx in g_restLengths) {    
                        text += "" + (idx/unit).toPrecision(6) + ":\t" + g_restLengths[idx] + "\n";
                    }
                    myTextBox2.text = text;
                    
                    // relist duration of notes and rests
                    helloQml3.text = 'Duration of notes:&nbsp;&nbsp;' + (noteLength/unit).toPrecision(6);
                    helloQml7.text = 'Duration of rests:&nbsp;&nbsp;' + (restLength/unit).toPrecision(6);
              }
        }
        
        Rectangle {
          color: "grey"
          //anchors.horizontalCenter: parent.horizontalCenter
          height: 1
          width: 460          
          x: 20
          y: 48
        }
        
        Rectangle {
          color: "white"
          //anchors.horizontalCenter: parent.horizontalCenter
          height: 1
          width: 460          
          x: 20
          y: 49
        }
        
        Label {
            //anchors.horizontalCenter: horizontalCenter
            x: 210
            y: 60
            text: qsTr("Summary")
            font.bold: true
        }
        
        Text {
            id: helloQml4
            //anchors.centerIn: parent
            x: 20
            y: 84            
            textFormat: Text.StyledText
            text: qsTr("Hello Qml")
        }
        
        Text {
            id: helloQml5
            //anchors.centerIn: parent
            x: 200
            y: 84            
            textFormat: Text.StyledText
            text: qsTr("Hello Qml")
        }
        
        Text {
            id: helloQml1
            //anchors.centerIn: parent
            x: 360
            y: 84            
            textFormat: Text.StyledText
            text: qsTr("Hello Qml")
        }
        
         Label {
            //anchors.horizontalCenter: horizontalCenter
            x: 215
            y: 110
            text: qsTr("Pitches")
            font.bold: true
        }
        
        ///////////
        Text {
            x: 20
            y: 134
            text: qsTr("Pitch")
        }
        
        Text {
            x: 92
            y: 134
            text: qsTr("Occur.")
        }
        
        Text {
            x: 170
            y: 134
            text: qsTr("Tot. len.")
        }
        
        ///////////
        Text {
            x: 270
            y: 134
            text: qsTr("Pitch")
        }
        
        Text {
            x: 342
            y: 134
            text: qsTr("Occur.")
        }
        
        Text {
            x: 420
            y: 134
            text: qsTr("Tot. len.")
        }     
        
        ///////////
        Label {
            x: 20
            y: 154
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("C")
            font.bold: true
        }
        
        Text {
          id: txtOcc0 //helloQmlC
            //anchors.centerIn: parent
            x: 90
            y: 154
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("66")
        }
        
        Text {
          id: txtLen0 //helloQmlCLength
            //anchors.centerIn: parent
            x: 174
            y: 154
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("41.5000")
        }
        
        Label {
            x: 20
            y: 174
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("C#/Db")
            font.bold: true
        }
        
        Text {
          id: txtOcc1 //helloQmlCis
            //anchors.centerIn: parent
            x: 90
            y: 174
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("666")
        }
        
        Text {
          id: txtLen1 //helloQmlCisLength
            //anchors.centerIn: parent
            x: 174
            y: 174
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("94.0000")
        }
        
        Label {
            x: 20
            y: 194
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("D")
            font.bold: true
        }
        
        Text {
          id: txtOcc2 //helloQmlD
            //anchors.centerIn: parent
            x: 90
            y: 194
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("66")
        }
        
        Text {
          id: txtLen2 //helloQmlDLength
            //anchors.centerIn: parent
            x: 174
            y: 194
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("41.5000")
        }
        
        Label {
            x: 20
            y: 214
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("D#/Eb")
            font.bold: true
        }
        
        Text {
          id: txtOcc3 //helloQmlDis
            //anchors.centerIn: parent
            x: 90
            y: 214
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("666")
        }
        
        Text {
          id: txtLen3 //helloQmlDisLength
            //anchors.centerIn: parent
            x: 174
            y: 214
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("94.0000")
        }
        
        Label {
            x: 20
            y: 234
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("E")
            font.bold: true
        }
        
        Text {
          id: txtOcc4 //helloQmlE
            //anchors.centerIn: parent
            x: 90
            y: 234
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("66")
        }
        
        Text {
          id: txtLen4 //helloQmlELength
            //anchors.centerIn: parent
            x: 174
            y: 234
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("41.5000")
        }
        
        Label {
            x: 20
            y: 254
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("F")
            font.bold: true
        }
        
        Text {
          id: txtOcc5 //helloQmlF
            //anchors.centerIn: parent
            x: 90
            y: 254
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("666")
        }
        
        Text {
          id: txtLen5 //helloQmlFLength
            //anchors.centerIn: parent
            x: 174
            y: 254            
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("94.0000")
        }
        
        ///////////
        Label {
            x: 270
            y: 154
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("F#/Gb")
            font.bold: true
        }
        
        Text {
          id: txtOcc6 //helloQmlFis
            //anchors.centerIn: parent
            x: 340
            y: 154
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("66")
        }
        
        Text {
          id: txtLen6 //helloQmlFisLength
            //anchors.centerIn: parent
            x: 426
            y: 154
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("41.5000")
        }
        
        Label {
            x: 270
            y: 174
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("G")
            font.bold: true
        }
        
        Text {
          id: txtOcc7 //helloQmlG
            //anchors.centerIn: parent
            x: 340
            y: 174
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("666")
        }
        
        Text {
          id: txtLen7 //helloQmlGLength
            //anchors.centerIn: parent
            x: 426
            y: 174
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("94.0000")
        }
        
        Label {
            x: 270
            y: 194
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("G#/Ab")
            font.bold: true
        }
        
        Text {
          id: txtOcc8 //helloQmlGis
            //anchors.centerIn: parent
            x: 340
            y: 194
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("66")
        }
        
        Text {
          id: txtLen8 //helloQmlGisLength
            //anchors.centerIn: parent
            x: 426
            y: 194
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("41.5000")
        }
        
        Label {
            x: 270
            y: 214
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("A")
            font.bold: true
        }
        
        Text {
          id: txtOcc9 //helloQmlA
            //anchors.centerIn: parent
            x: 340
            y: 214
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("666")
        }
        
        Text {
          id: txtLen9 //helloQmlALength
            //anchors.centerIn: parent
            x: 426
            y: 214
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("94.0000")
        }
        
        Label {
            x: 270
            y: 234
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("A#/Bb")
            font.bold: true
        }
        
        Text {
          id: txtOcc10 //helloQmlAis
            //anchors.centerIn: parent
            x: 340
            y: 234
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("66")
        }
        
        Text {
          id: txtLen10 //helloQmlAisLength
            //anchors.centerIn: parent
            x: 426
            y: 234
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("41.5000")
        }
        
        Label {
            x: 270
            y: 254
            width: 40
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("B")
            font.bold: true
        }
        
        Text {
          id: txtOcc11 //helloQmlB
            //anchors.centerIn: parent
            x: 340
            y: 254
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("666")
        }
        
        Text {
          id: txtLen11 //helloQmlBLength
            //anchors.centerIn: parent
            x: 426
            y: 254            
            width: 40
            horizontalAlignment: Text.AlignRight
            text: qsTr("94.0000")
        }
        
        ///////////
        Rectangle {
          color: "grey"
          //anchors.horizontalCenter: parent.horizontalCenter
          height: 1
          width: 460          
          x: 20
          y: 280
        }
        
        Rectangle {
          color: "white"
          //anchors.horizontalCenter: parent.horizontalCenter
          height: 1
          width: 460          
          x: 20
          y: 281
        }
        
        Label {
            x: 20
            y: 290
            text: qsTr("Occurences of note lengths:")
            font.bold: true
        }
        
        Label {
            x: 250
            y: 290
            text: qsTr("Occurences of rest lengths:")
            font.bold: true
        }
        
        TextArea 
        {
            id: myTextBox1
            x: 20
            y: 314
            //font.pointSize: 10
            //anchors.top: window.top
            //anchors.left: window.left
            //anchors.right: window.right
            anchors.topMargin: 35
            anchors.bottomMargin: 10
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            width: 225
            height: 150
            wrapMode: TextEdit.WrapAnywhere
            textFormat: TextEdit.PlainText
        }
        
        TextArea 
        {
            id: myTextBox2
            x: 255
            y: 314
            //font.pointSize: 10
            //anchors.top: window.top
            //anchors.left: window.left
            //anchors.right: window.right
            anchors.topMargin: 35
            anchors.bottomMargin: 10
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            width: 225
            height: 150
            wrapMode: TextEdit.WrapAnywhere
            textFormat: TextEdit.PlainText
        }
        
        Label {
            //anchors.horizontalCenter: horizontalCenter
            x: 224
            y: 474
            text: qsTr("Totals")
            font.bold: true
        }
        
        Text {
            id: helloQml2
            //anchors.centerIn: parent
            x: 20
            y: 496
            textFormat: Text.StyledText
            text: qsTr("Hello Qml")
        }
        
        Text {
            id: helloQml3
            //anchors.centerIn: parent
            x: 20
            y: 516
            textFormat: Text.StyledText
            text: qsTr("Hello Qml")
        }
        
        Text {
            id: helloQml6
            //anchors.centerIn: parent
            x: 250
            y: 496
            textFormat: Text.StyledText
            text: qsTr("Hello Qml")
        }
        
        Text {
            id: helloQml7
            //anchors.centerIn: parent
            x: 250
            y: 516
            textFormat: Text.StyledText
            text: qsTr("Hello Qml")
        }
        
        ///////////
        Rectangle {
          color: "grey"
          //anchors.horizontalCenter: parent.horizontalCenter
          height: 1
          width: 460          
          x: 20
          y: 538
        }
        
        Rectangle {
          color: "white"
          //anchors.horizontalCenter: parent.horizontalCenter
          height: 1
          width: 460          
          x: 20
          y: 539
        }
        
 
        Text {
            x: 108
            y: 554
            text: qsTr("(using")
        }
        
        Text {
            x: 238
            y: 554
            text: qsTr("as a unit)")
        }
        
        ComboBox {
              id: beatBase2
              width: 80
              height: 24            
              x: 152
              y: 550
              model: ListModel {
                    id: beatBaseList2
                    //mult is a tempo-multiplier compared to a crotchet 
                    ListElement { text: '64th';    unit: 30   } 
                    ListElement { text: '32th';    unit: 60   } 
                    ListElement { text: '16th';    unit: 120  } 
                    ListElement { text: '8th';     unit: 240  }  
                    ListElement { text: 'Quarter'; unit: 480  } // 1/4
                    ListElement { text: 'Half';    unit: 960  }
                    ListElement { text: 'Whole';   unit: 1920 }
              }
              currentIndex: 4
              //implicitHeight: 42
              style: ComboBoxStyle {
                    //textColor: '#000000'
                    //selectedTextColor: '#000000'
                    //font.family: 'Leland'
                    //font.pointSize: 18
                    padding.top: 5
                    padding.bottom: 5
              }
              onCurrentIndexChanged: {
                    //var unit = beatBase2.model.get(currentIndex).unit;
              }
        }
        
        
        
//        ListModel {
//          ListElement {
//              name: "Bill Smith"
//              number: "555 3264"
//          }
//          ListElement {
//              name: "John Brown"
//              number: "555 8426"
//          }
//          ListElement {
//              name: "Sam Wise"
//              number: "555 0473"
//          }
//      }
        
        
        TableView {
            x: 20
            y: 170
            width: 660
            height: 200
            visible: false
            //enabled: enabledCheck.checked

            TableViewColumn{ role: "number" ; title: "#" ; width: 50 ; resizable: true ; movable: true  }
            TableViewColumn{ role: "element" ; title: "Element" ; width: 70 ; resizable: true ; movable: true  }
            TableViewColumn{ role: "pitch"  ; title: "Pitch" ; width: 50 ;resizable: true ; movable: true }
            TableViewColumn{ role: "duration" ; title: "Duration" ; width: 70 ;resizable: true ; movable: true }
            TableViewColumn{ role: "voice" ; title: "Voice" ; width: 50 ;resizable: true ; movable: true }
            TableViewColumn{ role: "measure" ; title: "Measure" ; width: 70 ; resizable: true ; movable: true  }
            TableViewColumn{ role: "beat"  ; title: "Beat" ; width: 70 ;resizable: true ; movable: true }
            TableViewColumn{ role: "staff" ; title: "Staff" ; width: 50 ;resizable: true ; movable: true }
            TableViewColumn{ role: "part" ; title: "Part" ; width: 120 ;resizable: true ; movable: true }
            
            model: ListModel{
                id: tV
            }
            

            // TODO: sorting when clicking column headers
            //sortingEnabled: true
            
            alternatingRowColors: true
            backgroundVisible: true
            headerVisible: true
            itemDelegate: Item {
                Text {                      
    //              anchors.verticalCenter: parent.verticalCenter
    //              color: "blue"
    //              if (enabledCheck.checked = false)
    //                        color: "gray"
    //              enabled: enabledCheck.checked // this causes delay
    //              elide: styleData.elideMode
                    text: styleData.value // need this to get text
                    } // Text
                } // Item
        }// TableView
        
        
        
        

//        MouseArea {
//            anchors.fill: parent
//            onClicked: Qt.quit()
//        }


        MessageDialog {
            id: messageDialog
            title: "May I have your attention please"
            text: "It's so cool that you are using Qt Quick."
            //modality: Qt.NonModal
            onAccepted: {
                console.log("And of course you could only agree.")
                txtSaved.text = msg;
                //Qt.quit()
            }
            Component.onCompleted: visible = false
        }


        Text {
            id: txtSaved
            //anchors.centerIn: parent
            x: 20
            y: 580
            text: qsTr("")
        }
        
    





        Button {
            id: saveButton
            //Layout.columnSpan: 3
            //anchors.centerIn: parent
            // Anchored to 20px off the top right corner of the parent
            //anchors.right: parent.right
            //anchors.bottom: parent.bottom
            //anchors.rightMargin: 20
            //anchors.bottomMargin: 20 
            x: 20
            y: 550
            
            text: qsTranslate("PrefsDialogBase", "Save .csv")
            onClicked: {
                // Save notelist
                //var ret = saveNotelist()
                // Save scorestats
                var ret = saveScorestats()
                if ( ret[0] == true ) {             
                    // Show message
                    messageDialog.icon = StandardIcon.Information
                    messageDialog.title = qsTr("Test")
                    messageDialog.text = qsTr("File saved in " + ret[1])
                } else {
                    messageDialog.icon = StandardIcon.Critical
                    messageDialog.title = qsTr("Test")
                    messageDialog.text = qsTr("Could not save " + ret[1])                   
                }
                
                //messageDialog.onAccepted: {
                //}
                
                messageDialog.visible = true
                //Qt.quit()
            }
        }
        
        Button {
            id: doneButton
            //Layout.columnSpan: 3
            //anchors.centerIn: parent
            // Anchored to 20px off the top right corner of the parent
            //anchors.right: parent.right
            //anchors.bottom: parent.bottom
            //anchors.rightMargin: 20
            //anchors.bottomMargin: 20 
            x: 400
            y: 550
            
            text: qsTranslate("PrefsDialogBase", "Done")
            onClicked: {
                //pluginId.parent.Window.window.close();
                Qt.quit()
            }
        }
    }
}
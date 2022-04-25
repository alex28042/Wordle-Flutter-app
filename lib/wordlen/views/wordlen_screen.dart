// ignore_for_file: unrelated_type_equality_checks

import 'dart:ffi';
import 'dart:math';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:wordless/app/app_colors.dart';
import 'package:wordless/wordlen/data/word_list.dart';
import 'package:wordless/wordlen/models/letter_model.dart';
import 'package:wordless/wordlen/models/word_model.dart';
import 'package:wordless/wordlen/widgets/board.dart';
import 'package:wordless/wordlen/widgets/keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameStatus { playing, submitting, lost, won }

class WordlenScreen extends StatefulWidget {
  const WordlenScreen({Key? key}) : super(key: key);

  @override
  State<WordlenScreen> createState() => _WordlenScreenState();
}

class _WordlenScreenState extends State<WordlenScreen> {
  GameStatus _gameStatus = GameStatus.playing;
  InterstitialAd? _interstitialAd;
  int _numInterstitialLoadAttempts = 0;
  final int maxFailedLoadAttempts = 3;
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  late Future<int> _wins;
  late Future<int> _lost;

  Future<void> _incrementWin() async {
    final SharedPreferences preferences = await _prefs;
    final int wins = (preferences.getInt('wins') ?? 0) + 1;
    setState(() {
      _wins = preferences.setInt("wins", wins).then((bool success) {
        return wins;
      });
    });
  }

  Future<void> _incrementLost() async {
    final SharedPreferences preferences = await _prefs;
    final int lost = (preferences.getInt('lost') ?? 0) + 1;
    setState(() {
      _lost = preferences.setInt("lost", lost).then((bool success) {
        return lost;
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _wins = _prefs.then((SharedPreferences preferences) {
      return (preferences.getInt('wins') ?? 0);
    });
    _lost = _prefs.then((SharedPreferences preferences) {
      return (preferences.getInt('lost') ?? 0);
    });
  }

  // ignore: unused_element
  void _createInterstitialAd() {
    InterstitialAd.load(
        adUnitId: 'ca-app-pub-3066040266554796/9225338461',
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            print('$ad loaded');
            _interstitialAd = ad;
            _numInterstitialLoadAttempts = 0;
            _interstitialAd!.setImmersiveMode(true);
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('InterstitialAd failed to load: $error.');
            _numInterstitialLoadAttempts += 1;
            _interstitialAd = null;
            if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
              _createInterstitialAd();
            }
          },
        ));
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) {
      print('Warning: attempt to show interstitial before loaded.');
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) =>
          print('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        _createInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _createInterstitialAd();
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  final List<Word> _board = List.generate(
    6,
    (_) => Word(letters: List.generate(5, (index) => Letter.empty())),
  );

  final List<List<GlobalKey<FlipCardState>>> _flipCardKeys = List.generate(
    6,
    (_) => List.generate(5, (_) => GlobalKey<FlipCardState>()),
  );

  int _currentWordIndex = 0;

  Word? get _currentWord =>
      _currentWordIndex < _board.length ? _board[_currentWordIndex] : null;

  // ignore: prefer_final_fields
  Word _solution = Word.fromString(
    fiveLetterWords[Random().nextInt(fiveLetterWords.length)].toUpperCase(),
  );
  final styleQuestion = const TextStyle(
      fontFamily: 'SFPro', fontSize: 17, fontWeight: FontWeight.normal);

  final Set<Letter> _keyboardLetters = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Center(
          child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20.0),
              child: IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return Dialog(
                          shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(18.0))),
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 20.0),
                            child: Column(
                              children: [
                                SizedBox(height: 16),
                                const Text(
                                  'CÓMO JUGAR',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 30),
                                ),
                                SizedBox(height: 12),
                                Text(
                                    'Adivina la palabra oculta en seis intentos.',
                                    style: styleQuestion),
                                SizedBox(height: 12),
                                Text(
                                  'Cada intento debe ser una palabra válida de 5 letras.',
                                  style: styleQuestion,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Después de cada intento el color de las letras cambia para mostrar qué tan cerca estás de acertar la palabra.',
                                  style: styleQuestion,
                                ),
                                Icon(
                                  Icons.abc,
                                  color: correctColor,
                                  size: 60.0,
                                ),
                                Text(
                                  'La letra está en la palabra y en la posición correcta.',
                                  style: styleQuestion,
                                ),
                                SizedBox(height: 12),
                                Icon(
                                  Icons.abc,
                                  color: inWordColor,
                                  size: 60.0,
                                ),
                                Text(
                                  'La letra está en la palabra pero en la posición incorrecta.',
                                  style: styleQuestion,
                                ),
                                SizedBox(height: 12),
                                Icon(
                                  Icons.abc,
                                  color: notInWordColor,
                                  size: 60.0,
                                ),
                                Text(
                                  'La letra no está en la palabra.',
                                  style: styleQuestion,
                                ),
                                SizedBox(height: 50),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text('Cerrar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      });
                },
                icon: const Icon(Icons.question_mark_rounded),
              )),
        ),
        title: const Text(
          'WordlES',
          // ignore: unnecessary_const
          style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontFamily: 'SFPro'),
        ),
        actions: <Widget>[
          Align(
              alignment: Alignment.center,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FutureBuilder<int>(
                      future: _wins,
                      builder:
                          (BuildContext context, AsyncSnapshot<int> snapshot) {
                        switch (snapshot.connectionState) {
                          case ConnectionState.waiting:
                            return const CircularProgressIndicator();
                          default:
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else {
                              return Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  'Ganadas: ${snapshot.data}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    fontFamily: 'SFPro',
                                  ),
                                ),
                              );
                            }
                        }
                      },
                    ),
                    FutureBuilder<int>(
                      future: _lost,
                      builder:
                          (BuildContext context, AsyncSnapshot<int> snapshot) {
                        switch (snapshot.connectionState) {
                          case ConnectionState.waiting:
                            return const CircularProgressIndicator();
                          default:
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else {
                              return Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  'Perdidas: ${snapshot.data}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      fontFamily: 'SFPro'),
                                ),
                              );
                            }
                        }
                      },
                    ),
                  ],
                ),
              ))
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Board(board: _board, flipCardKeys: _flipCardKeys),
          const SizedBox(
            height: 80,
          ),
          Keyboard(
            onKeyTapped: _onKeyTapped,
            onDeleteTapped: _onDeleteTapped,
            onEnterTapped: _onEnterTapped,
            letters: _keyboardLetters,
          ),
        ],
      ),
    );
  }

  void _onKeyTapped(String val) {
    if (_gameStatus == GameStatus.playing) {
      setState(() => _currentWord?.addLetter(val));
    }
  }

  void _onDeleteTapped() {
    if (_gameStatus == GameStatus.playing) {
      setState(() => _currentWord?.removeLetter());
    }
  }

  Future<void> _onEnterTapped() async {
    if (_gameStatus == GameStatus.playing &&
        _currentWord != null &&
        !_currentWord!.letters.contains(Letter.empty()) &&
        fiveLetterWords.contains(_currentWord!.wordString.toLowerCase())) {
      _gameStatus = GameStatus.submitting;
      print('$_solution');
      for (var i = 0; i < _currentWord!.letters.length; i++) {
        final currentWordLetter = _currentWord!.letters[i];
        final currentSolutionLetter = _solution.letters[i];

        setState(() {
          if (currentWordLetter == currentSolutionLetter) {
            _currentWord!.letters[i] =
                currentWordLetter.copyWith(status: LetterStatus.correct);
          } else if (_solution.letters.contains(currentWordLetter)) {
            _currentWord!.letters[i] =
                currentWordLetter.copyWith(status: LetterStatus.inWord);
          } else {
            _currentWord!.letters[i] =
                currentWordLetter.copyWith(status: LetterStatus.notInWord);
          }
        });

        final letter = _keyboardLetters.firstWhere(
          (element) => element.val == currentWordLetter.val,
          orElse: () => Letter.empty(),
        );
        if (letter.status != LetterStatus.correct) {
          _keyboardLetters
              .removeWhere((element) => element.val == currentWordLetter.val);
          _keyboardLetters.add(_currentWord!.letters[i]);
        }

        await Future.delayed(
          const Duration(milliseconds: 150),
          () => _flipCardKeys[_currentWordIndex][i].currentState?.toggleCard(),
        );
      }

      _checkIfWinOrLoss();
    } else if (!fiveLetterWords
        .contains(_currentWord!.wordString.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        dismissDirection: DismissDirection.none,
        duration: const Duration(milliseconds: 1000),
        backgroundColor: Colors.redAccent[200],
        content: const Text(
          'Palabra escrita no está en el diccionario',
          style: TextStyle(color: Colors.white),
        ),
      ));
    }
  }

  void _checkIfWinOrLoss() {
    if (_currentWord!.wordString == _solution.wordString) {
      _gameStatus = GameStatus.won;
      _createInterstitialAd();
      _incrementWin();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        dismissDirection: DismissDirection.none,
        duration: const Duration(days: 1),
        backgroundColor: correctColor,
        content: const Text(
          'Has ganado',
          style: TextStyle(color: Colors.white),
        ),
        action: SnackBarAction(
          onPressed: () {
            _showInterstitialAd();
            _restart();
          },
          textColor: Colors.white,
          label: 'Nueva Partida',
        ),
      ));
    } else if (_currentWordIndex + 1 >= _board.length) {
      _gameStatus = GameStatus.lost;
      _createInterstitialAd();
      _incrementLost();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        dismissDirection: DismissDirection.none,
        duration: const Duration(days: 1),
        backgroundColor: Colors.redAccent[200],
        content: Text(
          'Has perdido! la palabra era: ${_solution.wordString} ',
          style: const TextStyle(color: Colors.white),
        ),
        action: SnackBarAction(
          onPressed: () {
            _showInterstitialAd();
            _restart();
          },
          textColor: Colors.white,
          label: 'Nueva Partida',
        ),
      ));
    } else {
      _gameStatus = GameStatus.playing;
    }
    _currentWordIndex += 1;
  }

  void _restart() {
    setState(() {
      _gameStatus = GameStatus.playing;
      _currentWordIndex = 0;
      _board
        ..clear()
        ..addAll(
          List.generate(
            6,
            (_) => Word(letters: List.generate(5, (_) => Letter.empty())),
          ),
        );
      _solution = Word.fromString(
        fiveLetterWords[Random().nextInt(fiveLetterWords.length)].toUpperCase(),
      );
      _flipCardKeys
        ..clear()
        ..addAll(
          List.generate(
            6,
            (_) => List.generate(5, (_) => GlobalKey<FlipCardState>()),
          ),
        );

      _keyboardLetters.clear();
    });
  }
}

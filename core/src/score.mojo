# core/src/score.mojo — the end-of-game score and the high-score table.
#
# Ported from finish / insertHighScore in index.html:1021-1031.
#
# The score is cash + bank - debt, so a player who borrowed heavily can finish
# negative. The high-score table keeps the top ten by score, and the JS sort is
# `Array.prototype.sort`, which is stable, so equal scores keep insertion order.
# The insertion sort below is stable for the same reason.

import world


struct FinishResult(Copyable, Movable):
    var score: Float64
    var dead: Bool
    var day: Int64

    def __init__(out self, score: Float64, dead: Bool, day: Int64):
        self.score = score
        self.dead = dead
        self.day = day


struct HighScore(Copyable, Movable):
    var name: String
    var score: Float64
    var day: Int64
    var dead: Bool
    var date: String

    def __init__(
        out self, name: String, score: Float64, day: Int64, dead: Bool, date: String
    ):
        self.name = name
        self.score = score
        self.day = day
        self.dead = dead
        self.date = date


comptime MAX_HIGH_SCORES = 10


def finish(ref game: world.World) -> FinishResult:
    return FinishResult(game.cash + game.bank - game.debt, game.dead, game.day)


def insert_high_score(mut scores: List[HighScore], entry: HighScore) -> Bool:
    # Beermat (docs/beermat-re.md, M-13): a score of 0 or below is never
    # recorded. Returns whether the entry was inserted.
    if entry.score <= 0:
        return False
    scores.append(entry.copy())
    # Stable insertion sort, descending by score: an equal score stays behind
    # the entry it was inserted after, matching the JS stable sort.
    var i = len(scores) - 1
    while i > 0:
        if scores[i].score > scores[i - 1].score:
            var tmp = scores[i - 1].copy()
            scores[i - 1] = scores[i].copy()
            scores[i] = tmp.copy()
            i -= 1
        else:
            break
    while len(scores) > MAX_HIGH_SCORES:
        _ = scores.pop()
    return True

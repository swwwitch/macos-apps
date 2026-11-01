"""Guard both UI and keyboard paths against reverting to exact-match filtering."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
s = (root/'Sources/NotMyType/FontCardsView.swift').read_text()
assert 'RatingFilter.matches(store.rating($0), selection: ratingFilter)' in s
assert 'RatingFilter.matches(store.rating(file), selection: ratingFilter) && store.selectedFiles.contains' in s
assert 'store.rating(file) == ratingFilter' not in s
assert 'L("以上")' in (root/'Sources/NotMyType/ContentView.swift').read_text()
print('PASS shared display/keyboard predicate and minimum-rating label')

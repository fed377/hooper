export interface EloInput {
  rating: number;
  opponentRating: number;
  result: 0 | 1;
  gamesPlayed: number;
  pointDiff: number;
}

export interface EloResult {
  delta: number;
  newRating: number;
}

export function kFactor(rating: number, gamesPlayed: number): number {
  if (gamesPlayed < 10) return 40;
  if (rating < 2000) return 20;
  return 10;
}

export function marginMultiplier(pointDiff: number): number {
  const bonus = Math.max(0, pointDiff - 2) * 0.05;
  return Math.min(1.5, 1 + bonus);
}

export function calculateElo(input: EloInput): EloResult {
  const {rating, opponentRating, result, gamesPlayed, pointDiff} = input;

  const dRating = opponentRating - rating;
  const expected = 1 / (1 + Math.pow(10, (dRating) / 400));
  const k = kFactor(rating, gamesPlayed);
  const margin = marginMultiplier(pointDiff);

  const delta = Math.round(k * margin * (result - expected));

  return {delta, newRating: rating + delta};
}
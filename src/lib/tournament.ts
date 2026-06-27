import type {
  HydratedMatch,
  HydratedPlayoffMatch,
  Match,
  Player,
  PlayoffMatch,
  Standing,
} from "../types";

export const TOTAL_ROUNDS = 5;
export const WIN_WEIGHT = 0.95;
export const POINT_DIFFERENTIAL_WEIGHT = 0.05;

export function rankingScore(standing: Pick<Standing, "wins" | "point_differential">) {
  return (
    WIN_WEIGHT * standing.wins +
    POINT_DIFFERENTIAL_WEIGHT * standing.point_differential
  );
}

export function byStandingRank(
  a: Standing & { player?: Player },
  b: Standing & { player?: Player },
) {
  const scoreDifference = rankingScore(b) - rankingScore(a);

  if (scoreDifference !== 0) return scoreDifference;
  if (b.wins !== a.wins) return b.wins - a.wins;
  if (b.point_differential !== a.point_differential) {
    return b.point_differential - a.point_differential;
  }
  return (a.player?.name ?? "").localeCompare(b.player?.name ?? "");
}

export function formatTeam(match: HydratedMatch, side: "A" | "B") {
  const team = side === "A" ? match.teamA : match.teamB;
  return `${team.player1.name} + ${team.player2.name}`;
}

export function hydrateMatches(
  matches: Match[],
  players: Player[],
): HydratedMatch[] {
  const playersById = new Map(players.map((player) => [player.id, player]));

  return matches
    .map((match) => {
      const teamAPlayer1 = playersById.get(match.team_a_player_1);
      const teamAPlayer2 = playersById.get(match.team_a_player_2);
      const teamBPlayer1 = playersById.get(match.team_b_player_1);
      const teamBPlayer2 = playersById.get(match.team_b_player_2);

      if (!teamAPlayer1 || !teamAPlayer2 || !teamBPlayer1 || !teamBPlayer2) {
        return null;
      }

      return {
        ...match,
        teamA: { player1: teamAPlayer1, player2: teamAPlayer2 },
        teamB: { player1: teamBPlayer1, player2: teamBPlayer2 },
      };
    })
    .filter((match): match is HydratedMatch => match !== null)
    .sort((a, b) => {
      if (a.round_number !== b.round_number) {
        return a.round_number - b.round_number;
      }
      return a.court_number - b.court_number;
    });
}

export function hydratePlayoffMatches(
  matches: PlayoffMatch[],
  players: Player[],
): HydratedPlayoffMatch[] {
  const playersById = new Map(players.map((player) => [player.id, player]));
  const stageOrder = { quarter: 0, semi: 1, final: 2 };

  return matches
    .map((match) => {
      const teamA =
        match.team_a_player_1 && match.team_a_player_2
          ? {
              player1: playersById.get(match.team_a_player_1),
              player2: playersById.get(match.team_a_player_2),
            }
          : null;
      const teamB =
        match.team_b_player_1 && match.team_b_player_2
          ? {
              player1: playersById.get(match.team_b_player_1),
              player2: playersById.get(match.team_b_player_2),
            }
          : null;

      return {
        ...match,
        teamA:
          teamA?.player1 && teamA.player2
            ? { player1: teamA.player1, player2: teamA.player2 }
            : null,
        teamB:
          teamB?.player1 && teamB.player2
            ? { player1: teamB.player1, player2: teamB.player2 }
            : null,
      };
    })
    .sort((a, b) => {
      if (a.stage !== b.stage) return stageOrder[a.stage] - stageOrder[b.stage];
      return a.match_number - b.match_number;
    });
}

export function formatPlayoffTeam(match: HydratedPlayoffMatch, side: "A" | "B") {
  const team = side === "A" ? match.teamA : match.teamB;
  if (!team) return "TBD";
  return `${team.player1.name} + ${team.player2.name}`;
}

export function isValidCappedScore(
  scoreA: number,
  scoreB: number,
  target: number,
  cap: number,
) {
  if (!Number.isInteger(scoreA) || !Number.isInteger(scoreB)) return false;
  if (scoreA < 0 || scoreB < 0 || scoreA === scoreB) return false;

  const winner = Math.max(scoreA, scoreB);
  const loser = Math.min(scoreA, scoreB);

  if (winner < target || winner > cap) return false;
  if (winner < cap && winner - loser < 2) return false;
  if (winner === cap && loser > cap - 1) return false;

  return true;
}

export function getRestingPlayers(
  players: Player[],
  matches: HydratedMatch[],
  roundNumber: number,
) {
  const playing = new Set<string>();
  matches
    .filter((match) => match.round_number === roundNumber)
    .forEach((match) => {
      playing.add(match.team_a_player_1);
      playing.add(match.team_a_player_2);
      playing.add(match.team_b_player_1);
      playing.add(match.team_b_player_2);
    });

  return players
    .filter((player) => !playing.has(player.id))
    .sort((a, b) => a.name.localeCompare(b.name));
}

export function getMatchOutcome(match: HydratedMatch, playerId: string) {
  if (!match.completed || match.score_a === null || match.score_b === null) {
    return "Pending";
  }

  const isTeamA =
    match.team_a_player_1 === playerId || match.team_a_player_2 === playerId;
  const won = isTeamA
    ? match.score_a > match.score_b
    : match.score_b > match.score_a;

  return won ? "Win" : "Loss";
}

export function getPlayerIdsForMatch(match: Match) {
  return [
    match.team_a_player_1,
    match.team_a_player_2,
    match.team_b_player_1,
    match.team_b_player_2,
  ];
}

export type Gender = "men" | "women";

export type Player = {
  id: string;
  name: string;
  gender: Gender;
  rating: number;
};

export type Match = {
  id: string;
  round_number: number;
  court_number: number;
  team_a_player_1: string;
  team_a_player_2: string;
  team_b_player_1: string;
  team_b_player_2: string;
  score_a: number | null;
  score_b: number | null;
  completed: boolean;
};

export type TournamentState = {
  id: number;
  current_round: number;
};

export type Standing = {
  player_id: string;
  wins: number;
  losses: number;
  points_for: number;
  points_against: number;
  point_differential: number;
  matches_played: number;
};

export type MatchTeam = {
  player1: Player;
  player2: Player;
};

export type HydratedMatch = Match & {
  teamA: MatchTeam;
  teamB: MatchTeam;
};

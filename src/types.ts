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

export type PlayoffStage = "quarter" | "semi" | "final";
export type PlayoffFormat = "semis" | "quarters";
export type FinalFormat = "single_21" | "best_of_3";

export type PlayoffMatch = {
  id: string;
  match_key: string;
  stage: PlayoffStage;
  match_number: number;
  team_a_seed: number | null;
  team_b_seed: number | null;
  team_a_player_1: string | null;
  team_a_player_2: string | null;
  team_b_player_1: string | null;
  team_b_player_2: string | null;
  score_a: number | null;
  score_b: number | null;
  final_format: FinalFormat;
  set1_a: number | null;
  set1_b: number | null;
  set2_a: number | null;
  set2_b: number | null;
  set3_a: number | null;
  set3_b: number | null;
  completed: boolean;
};

export type HydratedPlayoffMatch = PlayoffMatch & {
  teamA: MatchTeam | null;
  teamB: MatchTeam | null;
};

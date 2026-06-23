import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "../lib/supabase";
import { byStandingRank, hydrateMatches } from "../lib/tournament";
import type { HydratedMatch, Match, Player, Standing, TournamentState } from "../types";

type TournamentData = {
  players: Player[];
  matches: HydratedMatch[];
  standings: Array<Standing & { player: Player }>;
  tournamentState: TournamentState | null;
};

const emptyData: TournamentData = {
  players: [],
  matches: [],
  standings: [],
  tournamentState: null,
};

export function useTournament() {
  const [data, setData] = useState<TournamentData>(emptyData);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const fetchTournament = useCallback(async () => {
    if (!supabase) {
      setError("Supabase is not configured yet.");
      setIsLoading(false);
      return;
    }

    const [playersResult, matchesResult, standingsResult, stateResult] =
      await Promise.all([
        supabase.from("players").select("*").order("name"),
        supabase
          .from("matches")
          .select("*")
          .order("round_number")
          .order("court_number"),
        supabase.from("player_standings").select("*"),
        supabase
          .from("tournament_state")
          .select("*")
          .eq("id", 1)
          .maybeSingle(),
      ]);

    const failure =
      playersResult.error ||
      matchesResult.error ||
      standingsResult.error ||
      stateResult.error;

    if (failure) {
      setError(failure.message);
      setIsLoading(false);
      return;
    }

    const players = (playersResult.data ?? []) as Player[];
    const matches = hydrateMatches((matchesResult.data ?? []) as Match[], players);
    const playersById = new Map(players.map((player) => [player.id, player]));
    const standings = ((standingsResult.data ?? []) as Standing[])
      .map((standing) => {
        const player = playersById.get(standing.player_id);
        return player ? { ...standing, player } : null;
      })
      .filter(
        (standing): standing is Standing & { player: Player } =>
          standing !== null,
      )
      .sort(byStandingRank);

    setData({
      players,
      matches,
      standings,
      tournamentState: stateResult.data as TournamentState | null,
    });
    setError(null);
    setLastUpdated(new Date());
    setIsLoading(false);
  }, []);

  useEffect(() => {
    void fetchTournament();
  }, [fetchTournament]);

  useEffect(() => {
    const client = supabase;
    if (!client) return;

    const channel = client
      .channel("beach-not-pro-tour-live")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "players" },
        () => void fetchTournament(),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "matches" },
        () => void fetchTournament(),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "player_standings" },
        () => void fetchTournament(),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "tournament_state" },
        () => void fetchTournament(),
      )
      .subscribe();

    return () => {
      void client.removeChannel(channel);
    };
  }, [fetchTournament]);

  const saveScore = useCallback(
    async (matchId: string, scoreA: number, scoreB: number) => {
      if (!supabase) {
        throw new Error("Supabase is not configured yet.");
      }

      const { error: rpcError } = await supabase.rpc("save_match_score", {
        p_match_id: matchId,
        p_score_a: scoreA,
        p_score_b: scoreB,
      });

      if (rpcError) {
        throw new Error(rpcError.message);
      }

      await fetchTournament();
    },
    [fetchTournament],
  );

  const stats = useMemo(() => {
    const completedMatches = data.matches.filter((match) => match.completed).length;
    const totalMatches = data.matches.length;
    const progress =
      totalMatches === 0 ? 0 : Math.round((completedMatches / totalMatches) * 100);

    return {
      completedMatches,
      totalMatches,
      progress,
    };
  }, [data.matches]);

  return {
    ...data,
    ...stats,
    isLoading,
    error,
    lastUpdated,
    refresh: fetchTournament,
    saveScore,
  };
}

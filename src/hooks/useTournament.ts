import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "../lib/supabase";
import {
  byStandingRank,
  hydrateMatches,
  hydratePlayoffMatches,
} from "../lib/tournament";
import type {
  FinalFormat,
  HydratedMatch,
  HydratedPlayoffMatch,
  Match,
  Player,
  PlayoffFormat,
  PlayoffMatch,
  Standing,
  TournamentState,
} from "../types";

type TournamentData = {
  players: Player[];
  matches: HydratedMatch[];
  playoffMatches: HydratedPlayoffMatch[];
  standings: Array<Standing & { player: Player }>;
  tournamentState: TournamentState | null;
};

const emptyData: TournamentData = {
  players: [],
  matches: [],
  playoffMatches: [],
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

    const [
      playersResult,
      matchesResult,
      playoffMatchesResult,
      standingsResult,
      stateResult,
    ] =
      await Promise.all([
        supabase.from("players").select("*").order("name"),
        supabase
          .from("matches")
          .select("*")
          .order("round_number")
          .order("court_number"),
        supabase
          .from("playoff_matches")
          .select("*")
          .order("stage")
          .order("match_number"),
        supabase.from("player_standings").select("*"),
        supabase
          .from("tournament_state")
          .select("*")
          .eq("id", 1)
          .maybeSingle(),
      ]);

    const playoffTableMissing =
      playoffMatchesResult.error &&
      "code" in playoffMatchesResult.error &&
      playoffMatchesResult.error.code === "PGRST205";

    const failure =
      playersResult.error ||
      matchesResult.error ||
      (playoffTableMissing ? null : playoffMatchesResult.error) ||
      standingsResult.error ||
      stateResult.error;

    if (failure) {
      setError(failure.message);
      setIsLoading(false);
      return;
    }

    const players = (playersResult.data ?? []) as Player[];
    const matches = hydrateMatches((matchesResult.data ?? []) as Match[], players);
    const playoffMatches = hydratePlayoffMatches(
      (playoffTableMissing ? [] : (playoffMatchesResult.data ?? [])) as PlayoffMatch[],
      players,
    );
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
      playoffMatches,
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
        { event: "*", schema: "public", table: "playoff_matches" },
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
    async (
      matchId: string,
      scoreA: number,
      scoreB: number,
      adminPassword: string,
    ) => {
      if (!supabase) {
        throw new Error("Supabase is not configured yet.");
      }

      const { error: rpcError } = await supabase.rpc("save_match_score", {
        p_match_id: matchId,
        p_score_a: scoreA,
        p_score_b: scoreB,
        p_admin_password: adminPassword,
      });

      if (rpcError) {
        throw new Error(rpcError.message);
      }

      await fetchTournament();
    },
    [fetchTournament],
  );

  const resetTournament = useCallback(
    async (adminPassword: string) => {
      if (!supabase) {
        throw new Error("Supabase is not configured yet.");
      }

      const { error: rpcError } = await supabase.rpc("reset_tournament", {
        p_admin_password: adminPassword,
      });

      if (rpcError) {
        throw new Error(rpcError.message);
      }

      await fetchTournament();
    },
    [fetchTournament],
  );

  const initializePlayoffs = useCallback(
    async (adminPassword: string, format: PlayoffFormat) => {
      if (!supabase) {
        throw new Error("Supabase is not configured yet.");
      }

      const { error: rpcError } = await supabase.rpc("initialize_playoffs", {
        p_admin_password: adminPassword,
        p_format: format,
      });

      if (rpcError) {
        throw new Error(rpcError.message);
      }

      await fetchTournament();
    },
    [fetchTournament],
  );

  const savePlayoffScore = useCallback(
    async (
      playoffMatchId: string,
      scoreA: number,
      scoreB: number,
      adminPassword: string,
    ) => {
      if (!supabase) {
        throw new Error("Supabase is not configured yet.");
      }

      const { error: rpcError } = await supabase.rpc("save_playoff_score", {
        p_match_id: playoffMatchId,
        p_score_a: scoreA,
        p_score_b: scoreB,
        p_admin_password: adminPassword,
      });

      if (rpcError) {
        throw new Error(rpcError.message);
      }

      await fetchTournament();
    },
    [fetchTournament],
  );

  const saveFinalScore = useCallback(
    async (
      playoffMatchId: string,
      finalFormat: FinalFormat,
      sets: Array<[number, number]>,
      adminPassword: string,
    ) => {
      if (!supabase) {
        throw new Error("Supabase is not configured yet.");
      }

      const { error: rpcError } = await supabase.rpc("save_final_score", {
        p_match_id: playoffMatchId,
        p_final_format: finalFormat,
        p_set1_a: sets[0]?.[0] ?? null,
        p_set1_b: sets[0]?.[1] ?? null,
        p_set2_a: sets[1]?.[0] ?? null,
        p_set2_b: sets[1]?.[1] ?? null,
        p_set3_a: sets[2]?.[0] ?? null,
        p_set3_b: sets[2]?.[1] ?? null,
        p_admin_password: adminPassword,
      });

      if (rpcError) {
        throw new Error(rpcError.message);
      }

      await fetchTournament();
    },
    [fetchTournament],
  );

  const stats = useMemo(() => {
    const groupCompletedMatches = data.matches.filter((match) => match.completed).length;
    const groupTotalMatches = data.matches.length;
    const playoffTotalMatches = data.playoffMatches.length;
    const playoffCompletedMatches = data.playoffMatches.filter(
      (match) => match.completed,
    ).length;
    const completedMatches = groupCompletedMatches + playoffCompletedMatches;
    const totalMatches = groupTotalMatches + playoffTotalMatches;
    const progress =
      totalMatches === 0 ? 0 : Math.round((completedMatches / totalMatches) * 100);

    return {
      completedMatches,
      groupCompletedMatches,
      groupTotalMatches,
      playoffCompletedMatches,
      playoffTotalMatches,
      totalMatches,
      progress,
    };
  }, [data.matches, data.playoffMatches]);

  return {
    ...data,
    ...stats,
    isLoading,
    error,
    lastUpdated,
    refresh: fetchTournament,
    saveScore,
    resetTournament,
    initializePlayoffs,
    savePlayoffScore,
    saveFinalScore,
  };
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

// ============================================================
// SUPABASE CLIENT
// ============================================================
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ============================================================
// THEME MODE
// ============================================================
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// ============================================================
// AUTH STATE
// ============================================================
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

final currentUserProvider = Provider((ref) {
  return ref.watch(authStateProvider).valueOrNull?.session?.user;
});
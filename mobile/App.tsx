import React from "react";
import { StatusBar } from "expo-status-bar";
import { SafeAreaView, StyleSheet } from "react-native";
import DashboardScreen from "./src/screens/DashboardScreen";
import { colors } from "./src/theme";

export default function App() {
  return (
    <SafeAreaView style={styles.root}>
      <StatusBar style="light" backgroundColor={colors.bg} />
      <DashboardScreen />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
});

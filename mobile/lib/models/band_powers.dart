/// Normalised EEG frequency-band powers (sum ≈ 1).
class BandPowers {
  final double alpha;
  final double beta;
  final double theta;
  final double gamma;
  final double delta;

  const BandPowers({
    required this.alpha,
    required this.beta,
    required this.theta,
    required this.gamma,
    required this.delta,
  });

  Map<String, double> toJson() => {
    'alpha': alpha, 'beta': beta, 'theta': theta,
    'gamma': gamma, 'delta': delta,
  };
}

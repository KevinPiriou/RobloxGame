--!strict

-- Score local a une run : il recompense la distance parcourue a pied,
-- sans etre une monnaie ni une progression persistante.
return {
	UpdateRemoteName = "RunScore_Update",
	SampleInterval = 0.15,
	PublishInterval = 0.45,
	PointsPerStud = 1,
	MaximumSampleDistance = 28,
}

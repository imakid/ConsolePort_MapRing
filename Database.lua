local _, Data = CPAPI.LinkEnv(...)
---------------------------------------------------------------
ConsolePort:AddVariables({
---------------------------------------------------------------
	mapRingScale = _{Data.Range(1.0, 0.05, 0.5, 2);
		name = 'Map Ring Scale';
		desc = 'Scale of the map navigation ring.';
	};
	mapRingFontSize = _{Data.Range(13, 1, 8, 20);
		name = 'Font Size';
		desc = 'Font size of the map ring slice buttons.';
	};
})

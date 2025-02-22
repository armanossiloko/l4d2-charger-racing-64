enum struct Points {
	StringMap data;

	void Init() {
		this.data = new StringMap();
	}

	void Set(Modes mode, const char[] key, any value) {
		char buffer[256];
		FormatEx(buffer, sizeof(buffer), "%i-%s", mode, key);
		this.data.SetValue(buffer, value);
	}

	any Get(Modes mode, const char[] key) {
		char buffer[256];
		FormatEx(buffer, sizeof(buffer), "%i-%s", mode, key);
		any value;
		this.data.GetValue(buffer, value);
		return value;
	}

	void Clear() {
		this.data.Clear();
	}
}

void ParsePoints(const char[] file) {
	g_Points.Clear();

	KeyValues kv = new KeyValues("points");
	int total;

	if (kv.ImportFromFile(file) && kv.GotoFirstSubKey()) {
		char mode[64]; Modes index;
		do {
			kv.GetSectionName(mode, sizeof(mode));

			index = GetMode(mode);

			if (index == view_as<Modes>(-1)) {
				continue;
			}

			if (kv.GotoFirstSubKey(false)) {
				char key[64]; any value;
				do {
					kv.GetSectionName(key, sizeof(key));
					if (kv.GetDataType(NULL_STRING) == KvData_Float) {
						value = kv.GetFloat(NULL_STRING);
					} else {
						value = kv.GetNum(NULL_STRING);
					}
					g_Points.Set(index, key, value);
					total++;
				} while (kv.GotoNextKey(false));

				kv.GoBack();
			}

		} while (kv.GotoNextKey());
	}

	delete kv;
	ModeLog("Parsed %i point values from file: %s", total, file);
}
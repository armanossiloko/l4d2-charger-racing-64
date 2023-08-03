enum struct Points {
	StringMap data;

	void Init() {
		this.data = new StringMap();
	}

	void Set(Modes mode, const char[] key, int value) {
		char buffer[256];
		FormatEx(buffer, sizeof(buffer), "%i-%s", mode, key);
		this.data.SetValue(buffer, value);
	}

	int Get(Modes mode, const char[] key) {
		char buffer[256];
		FormatEx(buffer, sizeof(buffer), "%i-%s", mode, key);
		int value;
		this.data.GetValue(buffer, value);
		return value;
	}

	void Clear() {
		this.data.Clear();
	}
}
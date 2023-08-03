enum struct Track {
	char name[64];			//The name of the track to be displayed and called.
	Difficulty difficulty;	//The difficulty of the track, this is just an arbitrary value set when creating or editing the track.
	
	//Nodes
	ArrayList nodes;		//The list of origin points for the track which consists of 3D vectors in order. Index 0 is the start and the last index is the finish line.
	ArrayList colors;		//The colors that correspond to the beams of the track in corresponding order.

	void Init() {
		this.nodes = new ArrayList(3);
		this.colors = new ArrayList(4);
	}

	void Set(const char[] name, Difficulty difficulty) {
		strcopy(this.name, sizeof(Track::name), name);
		this.difficulty = difficulty;
	}

	void AddNode(float origin[3], int colors[4]) {
		this.nodes.PushArray(origin, sizeof(origin));
		this.colors.PushArray(colors, sizeof(colors));
	}

	void SetNode(int index, float origin[3], int colors[4]) {
		this.nodes.SetArray(index, origin, sizeof(origin));
		this.colors.SetArray(index, colors, sizeof(colors));
	}

	void SetNodeOrigin(int index, float origin[3]) {
		this.nodes.SetArray(index, origin, sizeof(origin));
	}

	void SetNodeColor(int index, int colors[4]) {
		this.colors.SetArray(index, colors, sizeof(colors));
	}

	int GetTotalNodes() {
		return this.nodes.Length;
	}

	void GetNode(int index, float origin[3], int colors[4]) {
		this.nodes.GetArray(index, origin, sizeof(origin));
		this.colors.GetArray(index, colors, sizeof(colors));
	}

	void GetNodeOrigin(int index, float origin[3]) {
		this.nodes.GetArray(index, origin, sizeof(origin));
	}

	void GetNodeColor(int index, int colors[4]) {
		this.colors.GetArray(index, colors, sizeof(colors));
	}

	void DeleteNode(int index) {
		this.nodes.Erase(index);
		this.colors.Erase(index);
	}

	void Clear() {
		this.nodes.Clear();
		this.colors.Clear();
	}

	void Delete() {
		this.name[0] = '\0';
		this.difficulty = DIFFICULTY_EASY;
		delete this.nodes;
		delete this.colors;
	}
}
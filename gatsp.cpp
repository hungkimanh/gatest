#include <iostream>
#include <vector>
#include <fstream>
#include <sstream>
#include <cmath>
#include <algorithm>
#include <random>
#include <limits>
#include <iomanip>
#include <numeric>
using namespace std;
struct GaElement {
    int c1 , r1 ,c2 ,r2 ; 
};
struct solution {
    vector<vector<int>> routes;
    double totalCost;
};
double euclidDist(double x1, double y1, double x2, double y2) {
    return round(sqrt((x1-x2)*(x1-x2) + (y1-y2)*(y1-y2)) * 100.0) / 100.0;
};
// Đọc dữ liệu CVRP chuẩn TSPLIB
void readCVRP(const string& filename, int& n, int& capacity, vector<pair<double,double>>& coords, vector<int>& demand, int& depot) {
    ifstream file (filename);
    if (!file.is_open()) {
        cerr << "Khong the mo file " << filename << endl;
        exit(1);
    }
    string line; 
    n=0; capacity=0; depot=0;
    while (getline(file, line)) {
        if (line.find("DIMENSION") != string::npos) {
            size_t pos = line.find(":");
            n = stoi(line.substr(pos+1));
        }
        if (line.find("CAPACITY") != string::npos) {
            size_t pos = line.find(":");
            capacity = stoi(line.substr(pos+1));
        }
        if (line.find("NODE_COORD_SECTION") != string::npos) break;
    }
      for (int i = 1; i <= n; ++i) {
        int idx;
        double x, y;
        file >> idx >> x >> y;
        coords[idx] = {x, y};
    }
    while (getline(file, line)) {
        if (line.find("DEMAND_SECTION") != string::npos) break;
    }
    demand.resize(n+1);
    for (int i = 1; i <= n; ++i) {
        int idx, d;
        file >> idx >> d;
        demand[idx] = d;
    }
    while (getline(file, line)) {
        if (line.find("DEPOT_SECTION") != string::npos) break;
    }
    file >> depot;
    // Bỏ qua -1 và EOF
    if (file.eof()) {
        cerr << "File ket thuc bat ngo!" << endl;
        exit(1);
    }
}

// Tạo ma trận khoảng cách
vector<vector<double>> buildDist(const vector<pair<double,double>>& coords) {
    int n = coords.size() - 1;
    vector<vector<double>> dist(n+1, vector<double>(n+1, 0));
    for (int i = 1; i <= n; ++i)
        for (int j = 1; j <= n; ++j)
            dist[i][j] = euclidDist(coords[i].first, coords[i].second, coords[j].first, coords[j].second);
    return dist;
}

int routeDemand(const vector<int>& route, const vector<int>& demand) {
    int sum = 0;
    for (size_t i = 1; i < route.size() - 1; ++i)
        sum += demand[route[i]];
    return sum;
}

double routeCost(const vector<int>& route, const vector<vector<double>>& dist) {
    double cost = 0;
    for (size_t i = 0; i < route.size() - 1; ++i)
        cost += dist[route[i]][route[i+1]];
    return round(cost * 100.0) / 100.0;
}

double totalCost(const vector<vector<int>>& routes, const vector<vector<double>>& dist) {
    double sum = 0;
    for (const auto& r : routes) sum += routeCost(r, dist);
    return round(sum * 100.0) / 100.0;
}
bool checkSolution(const vector<vector<int>>& routes, const vector<int>& demand, int capacity, int n) {
    vector<bool> visited(n+1, false);
    for (const auto& route : routes) {
        if (routeDemand(route, demand) > capacity) return false;
        for (size_t i = 1; i < route.size() - 1; ++i) {
            if (visited[route[i]]) return false;
            visited[route[i]] = true;
        }
    }
    for (int i = 2; i <= n; ++i)
        if (!visited[i]) return false;
    return true;
}
vector<vector<int>> initsolution(int vehicle, int n, int capacity, const vector<int>& demand ){
    //1. Tạo danh sách các khách hàng và xáo trộn
    vector<vector<int>> daycacxe; 
    int socathe = 50 ; 
    vector<int> khachhang; 
    for (int j = 2; j <= n; j ++){
            khachhang.push_back(j); 
        }
    random_device rd;
    mt19937 g(rd()); 
    shuffle(khachhang.begin(), khachhang.end(), g);
    //2. Chia khách hàng thành các nhóm thoả mãn capacity 
    vector<vector<int>>nhom ; 
    vector<int> xe ; 
    int tong = 0 ; 
    for(int i =0 ; i < khachhang.size(); i++){
        if (tong + demand[khachhang[i]]<= capacity){
            xe.push_back(khachhang[i]);
            tong += demand[khachhang[i]];
        }
        else{
            nhom.push_back(xe);
            xe.clear();
            tong = demand[khachhang[i]];
            xe.push_back(khachhang[i]);
        }

    }
    if (!xe.empty()) nhom.push_back(xe);
   // Nếu số nhóm < số xe, thêm các route rỗng
    while (nhom.size() < vehicle) {
        nhom.push_back({});
    }   
    //Ghép các nhóm lại thành dãy n-1 + vehicle -1 số 0 giữa các nhóm 
    vector<int> seq; 
    for (int i = 0 ; i < nhom.size(); i ++){
        for (int j = 0 ; j < nhom[i].size(); j ++){
            seq.push_back(nhom[i][j]);
        }
        if (i != nhom.size() -1) seq.push_back(0); // Thêm số 0 giữa các nhóm, trừ nhóm cuối
    }
   
    return nhom;
}
vector<vector<int>> initPopulationSeq(int vehicle, int n, int capacity, const vector<int>& demand) {
    vector<vector<int>> populationSeq;
    int population = 50; // Số lượng cá thể

    random_device rd;
    mt19937 gen(rd());

    for (int p = 0; p < population; ++p) {
        // 1. Tạo danh sách khách hàng và xáo trộn
        vector<int> customers;
        for (int i = 2; i <= n; ++i) customers.push_back(i);
        shuffle(customers.begin(), customers.end(), gen);

        // 2. Chia khách hàng thành các nhóm (route) thoả mãn capacity
        vector<vector<int>> groups;
        vector<int> currentGroup;
        int currentLoad = 0;
        for (int cust : customers) {
            if (currentLoad + demand[cust] <= capacity) {
                currentGroup.push_back(cust);
                currentLoad += demand[cust];
            } else {
                groups.push_back(currentGroup);
                currentGroup = {cust};
                currentLoad = demand[cust];
            }
        }
        if (!currentGroup.empty()) groups.push_back(currentGroup);

        // 3. Nếu số nhóm < vehicle, thêm nhóm rỗng để đủ số xe
        while ((int)groups.size() < vehicle) groups.push_back({});

        // 4. Ghép các nhóm lại thành dãy n-1 + vehicle-1, chèn 0 giữa các nhóm
        vector<int> seq;
        for (size_t i = 0; i < groups.size(); ++i) {
            for (int cust : groups[i]) seq.push_back(cust);
            if (i != groups.size() - 1) seq.push_back(0); // chèn 0 giữa các nhóm
        }

        populationSeq.push_back(seq);
    }
    return populationSeq;
}
void repairZero (vector<int>& seq , int vehicle){
    int zeroCount = count(seq.begin(), seq.end(), 0);
    int needZero = vehicle - 1 ; 
    while (zeroCount > needZero) {
        for (int i = 1; i < seq.size() - 1; i++) {
            if (seq[i] == 0 && (i == 0 || i == seq.size() - 1 || (i + 1 < seq.size() && seq[i + 1] == 0))) {
                seq.erase(seq.begin() + i);
                zeroCount--;
                if (zeroCount == needZero) break;
            }
            if (zeroCount > needZero) {
                auto it = find(seq.begin(), seq.end(), 0);
                if (it != seq.end()) {
                    seq.erase(it);
                    zeroCount--;
                }
                if (zeroCount == needZero) break;

            }
        }
    }
}
void repairCustomer (vector<int>&seq, int n ){
vector<int> count(n+1, 0);
for (int v : seq) if (v != 0) count[v]++;   
vector<int> missing;
for (int i = 2; i <= n; ++i) {
    if (count[i] == 0) missing.push_back(i);    
    int idx = 0;
    for (int& v : seq) {
        if (v != 0 && count[v] > 1) {
            v = missing[idx++];
            
            count[v]--;
            if (idx >= missing.size()) break;
        }
    }
} 
}
void generatePopulation(const string& filename, int vehicle) {
    // 1. Đọc dữ liệu
    int n, capacity, depot;
    vector<pair<double,double>> coords(1000); // Giả sử tối đa 1000 node
    vector<int> demand;
    readCVRP(filename, n, capacity, coords, demand, depot);

    // 2. Sinh quần thể dạng sequence
    vector<vector<int>> populationSeq = initPopulationSeq(vehicle, n, capacity, demand);

    // 3. Sửa từng cá thể nếu cần (đảm bảo hợp lệ)
    for (auto& seq : populationSeq) {
        repairZero(seq, vehicle);
        repairCustomer(seq, n);
    }

    // 4. In ra quần thể (tuỳ chọn)
    for (size_t i = 0; i < populationSeq.size(); ++i) {
        cout << "Individual " << i+1 << ": ";
        for (int v : populationSeq[i]) cout << v << " ";
        cout << endl;
    }
}
// Hàm giải mã dãy sequence thành các routemã dãy sequence thành các route
vector<vector<int>> decodeSeq(const vector<int>& seq, int depot) {
    vector<vector<int>> routes;
    vector<int> currentRoute = {depot};
    for (int v : seq) {
        if (v == 0) {
            currentRoute.push_back(depot);
            routes.push_back(currentRoute);
            currentRoute = {depot};
        } else {
            currentRoute.push_back(v);
        }
    }
    if (currentRoute.size() > 1) {
        currentRoute.push_back(depot);
        routes.push_back(currentRoute);
    }
    return routes;
}

// Hàm tìm cá thể tốt nhất trong quần thể
void findBestIndividual(const vector<vector<int>>& populationSeq, int depot, const vector<pair<double,double>>& coords) {
    vector<vector<double>> dist = buildDist(coords);
    double bestCost = numeric_limits<double>::max();
    int bestIdx = -1;
    for (size_t i = 0; i < populationSeq.size(); ++i) {
        vector<vector<int>> routes = decodeSeq(populationSeq[i], depot);
        double cost = totalCost(routes, dist);
        cout << "Individual " << i+1 << " cost: " << cost << endl;
        if (cost < bestCost) {
            bestCost = cost;
            bestIdx = i;
        }
    }
    cout << "Best individual is " << bestIdx+1 << " with cost = " << bestCost << endl;
}
void runCMT1() {
    string filename = "CMT1.txt";
    int vehicle = 5; // Số xe, bạn có thể thay đổi nếu cần

    // 1. Đọc dữ liệu
    int n, capacity, depot;
    vector<pair<double,double>> coords(1000);
    vector<int> demand;
    readCVRP(filename, n, capacity, coords, demand, depot);

    // 2. Sinh quần thể
    vector<vector<int>> populationSeq = initPopulationSeq(vehicle, n, capacity, demand);

    // 3. Sửa từng cá thể nếu cần
    for (auto& seq : populationSeq) {
        repairZero(seq, vehicle);
        repairCustomer(seq, n);
    }

    // 4. In ra quần thể
    for (size_t i = 0; i < populationSeq.size(); ++i) {
        cout << "Individual " << i+1 << ": ";
        for (int v : populationSeq[i]) cout << v << " ";
        cout << endl;
    }

    // 5. Tìm cá thể tốt nhất
    findBestIndividual(populationSeq, depot, coords);
}
int main() {
    runCMT1();
    return 0;
}



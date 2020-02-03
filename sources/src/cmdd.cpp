#include <csignal>
#include <filesystem>
#include <iostream>

#include <sdbus-c++/sdbus-c++.h>

#include "ConnManDispatcher/cmdd/config.hpp"

#ifdef NDEBUG
#define TRACE(x)
#else
#define TRACE(x)                                                                                                       \
    {                                                                                                                  \
        std::cout << "===> " << x << std::endl;                                                                        \
    }
#endif

using namespace sdbus;
using namespace std;

using Dbus = unique_ptr<IConnection>;
using Path = filesystem::path;

struct ConnManState
{
    Dbus   dbus;
    string current     = "unknown";
    bool   offlineMode = false;
} cmState;

void signalTrap(int)
{
    cout << Config::ProjectName << "::info: system signal catched, exiting...\n";
    cmState.dbus->leaveEventLoop();
}

string execCommand(const string& cmd)
{
    TRACE("executing: " << cmd);

    array<char, 128> buffer;
    string           result;

    unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);

    if (!pipe) { throw runtime_error("popen() failed!"); }

    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) { result += buffer.data(); }

    return result;
}

void onPropertyChanged(const string& name, const Variant& value)
{
#ifdef NDEBUG
    static const Path handler = Path(Config::InstallPrefix) / "share" / Path(Config::ProjectName) / "handler.sh";
#else
    static const Path handler = Path(Config::MainProjectName) / Path(Config::ProjectName) / "handler.sh";
#endif

    string newState;
    if (name == "State") newState = value.get<string>();

    if (name == "OfflineMode") cmState.offlineMode = value.get<bool>();

    if (!cmState.offlineMode && (cmState.current != newState))
    {
        string cmd = "/bin/bash -e " + handler.string() + " " + newState + " " + cmState.current;
        cout << execCommand(cmd);

        cmState.current = newState;
    }
}

int main(int, const char*[])
{
    const char* destName = "net.connman";
    const char* objPath  = "/";
    auto        cmProxy  = createProxy(destName, objPath);
    const char* cmIFace  = "net.connman.Manager";

    signal(SIGINT | SIGTERM, signalTrap);
    cout.setf(ios::unitbuf);

    {
        map<string, Variant> reply;
        cmProxy->callMethod("GetProperties").onInterface(cmIFace).storeResultsTo(reply);
        cmState.offlineMode = reply["OfflineMode"].get<bool>();
        onPropertyChanged("State", reply["State"]);
    }

    cmProxy->uponSignal("PropertyChanged").onInterface(cmIFace).call([](const string& name, const Variant& value) {
        onPropertyChanged(name, value);
    });

    cmProxy->finishRegistration();

    cmState.dbus = createSystemBusConnection();
    cmState.dbus->enterEventLoop();

    return 0;
}

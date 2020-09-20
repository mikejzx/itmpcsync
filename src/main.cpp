/*
 * main.c
 *
 * The main translation unit of the program.
 */

// Includes
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <unistd.h>

// Libraries
#include "plistcpp/Plist.hpp"

// Main defines.
#define PROGRAM "itxmlconvert"
#define OK 1
#define EXIT 0
#define FAIL 0
#define USAGE_INFO \
	"  Usage: " PROGRAM " LIBRARY\n"\
	"  Where LIBRARY is the location of the iTunes XML library.\n"

// Forward declarations.
int check_args(int, char**);
int lib_read(const std::string&);

/*
 * https://stackoverflow.com/a/5342157
 * A simple string escaper.
 */
struct escaper
{
	std::string& target;
	explicit escaper(std::string& t) : target(t) {}

	void operator() (char ch) const
	{
		// Replace double quotes with \\\"
		if (ch == '\"')
		{
			target.push_back('\\');
		}
		target.push_back(ch);
	}
};

// Main variables.
static std::string lib_path;

/*
 * Entry point to the program.
 *
 * @param argc  Number of args.
 * @param argv  Array of args.
 *
 * @return the status code.
 */
int main(int argc, char* argv[])
{
	// Check command-line arguments.
	if (!check_args(argc, argv))
	{
		// Terminate program.
		return 0;
	}

	// Read the XML library file.
	lib_read(lib_path);

	// Normal termination
	return 0;
}

/*
 * Reads the library at the path given into a buffer.
 *
 * @param path  The path of the library to read.
 *
 * @return OK if read successfully.
 */
int lib_read(const std::string& path)
{
	// Typedef this annoying type.
	typedef std::map<std::string, boost::any> xmldict;

	// Read the plist file.
	xmldict dict;
	Plist::readPlist(path.c_str(), dict);

	// Get the tracks dictionary.
	xmldict tracks = (xmldict)boost::any_cast<const xmldict&>(dict.find("Tracks")->second);

#ifdef JSON_OUT
	// Write beginning of JSON output.
	std::cout << "[\n";
#endif

	// Temporary string
	std::string tmp;

	// Iterate over all the tracks.
	for (auto it = tracks.begin(); it != tracks.end(); ++it)
	{
		// Get the dictionary for this track.
		xmldict t_dict = (xmldict)boost::any_cast<const xmldict&>(it->second);

		// Get track information.
		std::string t_title = "", t_artist = "", t_album = "";
		int t_pcount = 0;
		{
			// Shorten everything a bit.
			using namespace std;
			using namespace boost;

			// Get title.
			if (t_dict.find("Name") != t_dict.end())
			{
				t_title = (string)any_cast<const string&>(t_dict.find("Name")->second);

				// Escape quotes.
				tmp = "";
				std::for_each(t_title.begin(), t_title.end(), escaper(tmp));
				t_title = tmp;
			}

			// Get artist.
			if (t_dict.find("Artist") != t_dict.end())
			{
				t_artist = (string)any_cast<const string&>(t_dict.find("Artist")->second);

				// Escape quotes.
				tmp = "";
				std::for_each(t_artist.begin(), t_artist.end(), escaper(tmp));
				t_artist = tmp;
			}

			// Get album. We need this to help differentiate duplicate titles.
			if (t_dict.find("Album") != t_dict.end())
			{
				t_album = (string)any_cast<const string&>(t_dict.find("Album")->second);

				// Escape quotes.
				tmp = "";
				std::for_each(t_album.begin(), t_album.end(), escaper(tmp));
				t_album = tmp;
			}

			// Get playcount.
			if (t_dict.find("Play Count") != t_dict.end())
			{
				t_pcount = (int)any_cast<const int64_t&>(t_dict.find("Play Count")->second);
			}
		}

	#ifdef JSON_OUT
		// Print output in JSON
		if (it != tracks.begin())
		{
			std::cout << ",\n";
		}
		std::cout << "    {\n";
		std::cout << "        \"Title\": \"" << t_title << "\",\n";
		std::cout << "        \"Artist\": \"" << t_artist << "\",\n";
		std::cout << "        \"Album\": \"" << t_album << "\",\n";
		std::cout << "        \"Play Count\": " << t_pcount << "\n";
		std::cout << "    }";
	#else
		// Use a pipe-delimited output instead, which is much faster
		// to work with in our script.
		std::cout << t_title << "|" << t_album << "|" << t_artist << "|" << t_pcount << std::endl;
	#endif
	}

#ifdef JSON_OUT
	// Write end of JSON output.
	std::cout << "\n]\n"
#endif

	// Successfully read.
	return OK;
}

/*
 * Checks the given command-line arguments.
 *
 * @param argc  Number of args.
 * @param argv  Array of args.
 *
 * @return OK if program should continue, and EXIT if it should terminate.
 */
int check_args(int argc, char* argv[])
{
	// Check if we have command line arguments.
	if (argc <= 1) {
		std::cout << "Missing arguments" << std::endl;
		std::cout << USAGE_INFO << std::endl;
		return EXIT;
	}

	// Display help.
	if (
		strcmp(argv[1], "--help") == 0 ||
		strcmp(argv[1], "-h") == 0
	)
	{
		std::cout << USAGE_INFO << std::endl;
		return EXIT;
	}

	// Copy library path into a buffer.
	lib_path = std::string(argv[1]);

	return OK;
}

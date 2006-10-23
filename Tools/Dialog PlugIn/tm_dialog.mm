/*
    g++ -Wmost -arch ppc -arch i386 -isysroot /Developer/SDKs/MacOSX10.4u.sdk -DDATE=\"`date +%Y-%m-%d`\" -Os "$TM_FILEPATH" -o "$TM_SUPPORT_PATH/bin/tm_dialog" -framework Foundation && strip "$TM_SUPPORT_PATH/bin/tm_dialog"
*/
#import <Cocoa/Cocoa.h>
#import <getopt.h>
#import <fcntl.h>
#import <stdio.h>
#import <string.h>
#import <stdlib.h>
#import <unistd.h>
#import <errno.h>
#import <vector>
#import <string>
#import <sys/stat.h>

#import "Dialog.h"

char const* AppName = "tm_dialog";

char const* current_version ()
{
	char res[32];
	return sscanf("$Revision$", "$%*[^:]: %s $", res) == 1 ? res : "???";
}

id convert_object (id object)
{
	if([object isKindOfClass:[NSDictionary class]])
	{
		NSMutableDictionary* dict = [NSMutableDictionary dictionary];
		enumerate([object allKeys], id key)
			[dict setObject:convert_object([object objectForKey:key]) forKey:key];
		object = dict;
	}
	else if([object isKindOfClass:[NSArray class]])
	{
		NSMutableArray* array = [NSMutableArray array];
		enumerate(object, id member)
			[array addObject:convert_object(member)];
		object = array;
	}
	else if([object isKindOfClass:[NSIndexPath class]])
	{
		NSMutableArray* array = [NSMutableArray array];
		for(size_t i = 0; i < [object length]; ++i)
			[array addObject:[NSNumber numberWithUnsignedInt:[object indexAtPosition:i]]];
		object = array;
	}
	else if([object isKindOfClass:[NSIndexSet class]])
	{
		NSMutableArray* array = [NSMutableArray array];
		unsigned int buf[[object count]];
		[(NSIndexSet*)object getIndexes:buf maxCount:[object count] inIndexRange:nil];
		for(unsigned int i = 0; i != [object count]; i++)
			[array addObject:[NSNumber numberWithUnsignedInt:buf[i]]];
		object = array;
	}
	return object;
}

int contact_server (std::string nibName, NSMutableDictionary* someParameters, bool center, bool modal, bool quiet)
{
	int res = -1;

	id proxy = [NSConnection rootProxyForConnectionWithRegisteredName:@"TextMate dialog server" host:nil];
	[proxy setProtocolForProxy:@protocol(TextMateDialogServerProtocol)];

	if(!proxy)
	{
		fprintf(stderr, "%s: failed to establish connection with TextMate.\n", AppName);
	}
	else if([proxy textMateDialogServerProtocolVersion] == TextMateDialogServerProtocolVersion)
	{
		NSString* aNibPath = [NSString stringWithUTF8String:nibName.c_str()];

		NSDictionary* parameters = (NSDictionary*)[proxy showNib:aNibPath withParameters:someParameters modal:modal center:center];
		if(!quiet)
			printf("%s\n", [[convert_object(parameters) description] UTF8String]);
		res = [[parameters objectForKey:@"returnCode"] intValue];
	}
	else
	{
		fprintf(stderr, "%s: server version at v%d, this tool at v%d (they need to match)\n", AppName, [proxy textMateDialogServerProtocolVersion], TextMateDialogServerProtocolVersion);
	}
	return res;
}

void usage ()
{
	fprintf(stderr, 
		"%1$s r%2$s (" DATE ")\n"
		"Usage: %1$s [-cmqp] nib_file\n"
		"Options:\n"
		" -c, --center               Center the window on screen.\n"
		" -m, --modal                Show window as modal.\n"
		" -q, --quiet                Do not write result to stdout.\n"
		" -p, --parameters <plist>   Provide parameters as a plist.\n"
		"", AppName, current_version());
}

std::string find_nib (std::string nibName)
{
	std::vector<std::string> candidates;

	if(nibName.find(".nib") == std::string::npos)
		nibName += ".nib";

	if(nibName.size() && nibName[0] != '/') // relative path
	{
		if(char const* currentPath = getcwd(NULL, 0))
			candidates.push_back(currentPath + std::string("/") + nibName);

		if(char const* bundleSupport = getenv("TM_BUNDLE_SUPPORT"))
			candidates.push_back(bundleSupport + std::string("/nibs/") + nibName);

		if(char const* supportPath = getenv("TM_SUPPORT_PATH"))
			candidates.push_back(supportPath + std::string("/nibs/") + nibName);
	}
	else
	{
		candidates.push_back(nibName);
	}

	for(typeof(candidates.begin()) it = candidates.begin(); it != candidates.end(); ++it)
	{
		struct stat sb;
		if(stat(it->c_str(), &sb) == 0)
			return *it;
	}

	fprintf(stderr, "nib could not be loaded: %s (does not exist)\n", nibName.c_str());
	abort();
	return NULL;
}

int main (int argc, char* argv[])
{
	extern int optind;
	extern char* optarg;

	static struct option const longopts[] = {
		{ "center",				no_argument,			0,		'c'	},
		{ "modal",				no_argument,			0,		'm'	},
		{ "parameters",		required_argument,	0,		'p'	},
		{ "quiet",				no_argument,			0,		'q'	},
		{ 0,						0,							0,		0		}
	};

	bool center = false, modal = false, quiet = false;
	char const* parameters = NULL;
	char ch;
	while((ch = getopt_long(argc, argv, "cmp:q", longopts, NULL)) != -1)
	{
		switch(ch)
		{
			case 'c':	center = true;				break;
			case 'm':	modal = true;				break;
			case 'p':	parameters = optarg;		break;
			case 'q':	quiet = true;				break;
			default:		usage();						break;
		}
	}

	argc -= optind;
	argv += optind;

	int res = -1;
	if(argc == 1)
	{
		NSAutoreleasePool* pool = [NSAutoreleasePool new];

		NSMutableData* data = [NSMutableData data];
		if(parameters)
		{
			[data appendBytes:parameters length:strlen(parameters)];
		}
		else
		{
			if(isatty(STDIN_FILENO) == 0)
			{
				char buf[1024];
				while(size_t len = read(STDIN_FILENO, buf, sizeof(buf)))
					[data appendBytes:buf length:len];
			}
		}

		id plist = [data length] ? [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListMutableContainersAndLeaves format:nil errorDescription:NULL] : [NSMutableDictionary dictionary];
		res = contact_server(find_nib(argv[0]), plist, center, modal, quiet);
		[pool release];
	}
	else
	{
		usage();
	}
	return res;
}

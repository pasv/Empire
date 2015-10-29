from lib.common import helpers

class Module:

    def __init__(self, mainMenu, params=[]):

        # metadata info about the module, not modified during runtime
        self.info = {
            # name for the module that will appear in module menus
            'Name': 'Invoke-PivotFinder',

            # list of one or more authors for the module
            'Author': ['pasv'],

            # more verbose multi-line description of the module
            'Description': ('This script performs enumeration on a list of potential pivot hosts to identify if any of the hosts are able to connect by way of ping to any of the target hosts, in addition the script optionally check for a number of other indicators on the pivot host to identify connectivity such as RDP Saved Connection profiles, Putty saved sessions, Cygwin SSH known hosts, and in the future possibly others.'),

            # True if the module needs to run in the background
            'Background' : False,

            # File extension to save the file as
            'OutputExtension' : None,

            # True if the module needs admin rights to run
            'NeedsAdmin' : False, #sorta??? Needs remote admin

            # True if the method doesn't touch disk/is reasonably opsec safe
            'OpsecSafe' : True,
            
            # The minimum PowerShell version needed for the module to run
            'MinPSVersion' : '2',

            # list of any references/other comments
            'Comments': [
                'comment',
                'http://link/'
            ]
        }

        # any options needed by the module, settable during runtime
        self.options = {
            # format:
            #   value_name : {description, required, default_value}
            'Agent' : {
                # The 'Agent' option is the only one that MUST be in a module
                'Description'   :   'Agent to grab a screenshot from.',
                'Required'      :   True,
                'Value'         :   ''
            },
            'Pivots' : {
                'Description'   :   'Command to execute',
                'Required'      :   True,
                'Value'         :   'List of pivotss either - a filename, a CIDR, an IP address range, or invidiual addresses comma separated'
            },
            'Targets' : {
                'Description'   :   'Command to execute',
                'Required'      :   True,
                'Value'         :   'List of targets either - a filename, a CIDR, an IP address range, or invidiual addresses comma separated'
            },
            'CheckPutty' : {
                'Description'   :   'If enabled, Invoke-PivotFinder will access the remote registry of the pivot host to identify any saved connection profiles matching the targets',
                'Required'      :   False,
                'Value'         :   ''
            },
            'CheckCygwin' : {
                'Description'   :   'If enabled, Invoke-PivotFinder will access the remote file system of the pivot host and identify any and all users withost h SSH known hosts that match the targets',
                'Required'      :   False,
                'Value'         :   ''
            },
            'CheckRDP' : {
                'Description'   :   'If enabled, Invoke-PivotFinder will access the remote registry to identify saved connection profiles and identify if any are targets.',
                'Required'      :   False,
                'Value'         :   'test'
            },
            'Timeout' : {
                'Description'   :   'Timeout value is set for all pings remotely invoked on pivot hosts to remote targets.',
                'Required'      :   False,
                'Value'         :   '10'
            }
        }

        # save off a copy of the mainMenu object to access external functionality
        #   like listeners/agent handlers/etc.
        self.mainMenu = mainMenu

        # During instantiation, any settable option parameters
        #   are passed as an object set to the module and the
        #   options dictionary is automatically set. This is mostly
        #   in case options are passed on the command line
        if params:
            for param in params:
                # parameter format is [Name, Value]
                option, value = param
                if option in self.options:
                    self.options[option]['Value'] = value


    def generate(self):
        moduleSource = self.mainMenu.installPath + "/data/module_source/situational_awareness/network/Invoke-PivotFinder.ps1"
        try:
            f = open(moduleSource, 'r')
        except:
            print helpers.color("[!] Could not read module source path at: " + str(moduleSource))
            return ""

        moduleCode = f.read()
        f.close()

        script = moduleCode

        script += " Invoke-PivotFinder "

        # add any arguments to the end execution of the script
        for option,values in self.options.iteritems():
            if option.lower() != "agent":
                if values['Value'] and values['Value'] != '':
                    if values['Value'].lower() == "true":
                        # if we're just adding a switch
                        script += " -" + str(option)
                    else:
                        script += " -" + str(option) + " " + str(values['Value'])

        return script

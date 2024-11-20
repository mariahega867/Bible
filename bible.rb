
require 'webrick'
require 'json'

SCHEDULE_FILE = "schedule.json"
PROGRESS_FILE = "progress.json"

#load the scheduling
def loadSchedule
    JSON.parse(File.read(SCHEDULE_FILE))
end 



#load progress
def loadProgress
    JSON.parse(File.read(PROGRESS_FILE))
end

#save the progress
def saveProgress
    File.write(PROGRESS_FILE, progress.to_json)
end


#server
class BibleServer < WEBrick::HTTPServlet::AbstractServlet
    #display scheduled reading and saved progress
    def do_GET(request, response)
        if request.path == '/'
          progress = loadProgress
          schedule = loadSchedule
          day = progress["lastReadDay"]
          dailyReading = schedule[day.to_s]
          book = dailyReading["book"]
          chapter = dailyReading["chapter"]
          progress_percentage = (day.to_f / 365 * 100).round(2)

    
          response.status = 200
          response.content_type = 'text/html'
          response.body = "<html><body>
                            <h1>Today's Reading</h1>
                            <p>Book: #{book}</p>
                            <p>Chapter: #{chapter}</p>
                            <form action='/mark_done' method='post'>
                              <button type='submit'>Mark as Done</button>
                            </form>
                            <h2>Your Progress: #{progress_percentage}% completed</h2>
                          </body></html>"


        elsif request.path == '/mark_done'
          progress = loadProgress
          progress["lastReadDay"] += 1
          saveProgress(progress)
    
          response.status = 302
          response['Location'] = '/'


        else
          response.status = 404
          response.content_type = 'text/plain'
          response.body = "Page not found"

        end

      end

    end
    
    # Set up the server and map the path to our servlet
    server = WEBrick::HTTPServer.new(Port: 8080)
    server.mount "/", BibleServer
    
    trap 'INT' do
      server.shutdown
    end
    
    server.start
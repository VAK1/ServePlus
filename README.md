# ServePlus

![splash](https://tennisevolution.com/wp-content/uploads/2020/04/Toss-on-the-slice-serve-scaled.jpg)

Check it out on the [app store](https://apps.apple.com/us/app/serveplus/id1578581406)!
Check out the [technical documentation](https://drive.google.com/file/d/14JGiOjxp19xZ0cLAyLddBhJQ5qOOyBoE/view?usp=sharing) here!

ServePlus is an app that uses AI to help your tennis serve. Through pose detection and serve detection, improve your tennis serve on 8 feedback categories and graph your progress over time.

# Important parts of the repo

If you are looking for the meat of the repo look no further! Here it is.

<ins>For how my app's pose detection works:</ins>

[The function where](https://github.com/VAK1/ServePlus/blob/627ab82b50b2d1d8255bc9f09bab9a877348baa8/ServePlusDraft/Controllers/ServeAnalysisViewController.swift#L472) poses are detected (For the specific line, click [here](https://github.com/VAK1/ServePlus/blob/627ab82b50b2d1d8255bc9f09bab9a877348baa8/ServePlusDraft/Controllers/ServeAnalysisViewController.swift#L590))

[What happens](https://github.com/VAK1/ServePlus/blob/627ab82b50b2d1d8255bc9f09bab9a877348baa8/ServePlusDraft/Controllers/ServeAnalysisViewController.swift#L233) when poses are detected

<ins>For how my app's serve detection works:</ins>

[The function where](https://github.com/VAK1/ServePlus/blob/627ab82b50b2d1d8255bc9f09bab9a877348baa8/ServePlusDraft/Controllers/ServeAnalysisViewController.swift#L472) serves are detected (For the specific line, click [here](https://github.com/VAK1/ServePlus/blob/627ab82b50b2d1d8255bc9f09bab9a877348baa8/ServePlusDraft/Controllers/ServeAnalysisViewController.swift#L662))

[The function that handles serve detection](https://github.com/VAK1/ServePlus/blob/627ab82b50b2d1d8255bc9f09bab9a877348baa8/ServePlusDraft/Functions%20%2B%20Assets/Common.swift#L538)

What happens with the detected frames? [Click here](https://github.com/VAK1/ServePlus/blob/a455dc54b68e3c9763232a243493a047d77efa2b/ServePlusDraft/Controllers/ServeAnalysisViewController.swift#L670-L898)

<ins>For how my app's serve scoring works:</ins>

[Model references](https://github.com/VAK1/ServePlus/blob/a455dc54b68e3c9763232a243493a047d77efa2b/ServePlusDraft/Controllers/ServeAnalysisViewController.swift#L94-L101)

[Getting predictions](https://github.com/VAK1/ServePlus/blob/a455dc54b68e3c9763232a243493a047d77efa2b/ServePlusDraft/Controllers/ServeAnalysisViewController.swift#L907-L944)

# Todo

<ol>
  <li>For my own sanity, change all the for loops to mapping functions or vice versa - having both is such a relic</li>
  <li>Make the user interface for the FeedbackController more obvious</li>
  <li>Better buttons for the GraphController (actually, just a better GraphCotnroller) </li>
  <li>Is there a better way to store the feedback blurbs than a list of strings?</li>
  <li>I don't think the update alert shows if an update to ServePlus actually published </li>
  <li>ANDROID VERSION!!!</li>
  <li>Let the user know the app actually can detect multiple serves even if the user followed the tutorial.</li>
  <li>Utility to let the user share their pose-detected serve?</li>
  <li>Utility that shows the user ideal professional serves?</li>
</ol>

# Thanks for visiting!

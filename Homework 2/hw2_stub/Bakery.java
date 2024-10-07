import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Semaphore;
import java.util.concurrent.CountDownLatch;

public class Bakery implements Runnable {
    private static final int TOTAL_CUSTOMERS = 200;
    private static final int CAPACITY = 50;
    private static final int FULL_BREAD = 20;
    private Map<BreadType, Integer> availableBread;
    private ExecutorService executor;
    private float sales = 0;
    private CountDownLatch doneSignal = new CountDownLatch(TOTAL_CUSTOMERS);
    // TODO
    
    Semaphore ryeShelf = new Semaphore(1);
    Semaphore sourShelf = new Semaphore(1);
    Semaphore wonderShelf = new Semaphore(1);
    Semaphore cashier = new Semaphore(4);
    Semaphore cust_mutex = new Semaphore(CAPACITY);
    Semaphore update_sales = new Semaphore(1);
    
    
    /**
     * Remove a loaf from the available breads and restock if necessary
     */
    public void takeBread(BreadType bread) {
        int breadLeft = availableBread.get(bread);
        if (breadLeft > 0) {
            availableBread.put(bread, breadLeft - 1);
        } else {
            System.out.println("No " + bread.toString() + " bread left! Restocking...");
            // restock by preventing access to the bread stand for some time
            try {
                Thread.sleep(1000);
            } catch (InterruptedException ie) {
                ie.printStackTrace();
            }
            availableBread.put(bread, FULL_BREAD - 1);
        }
    }

    /**
     * Add to the total sales
     */
    public void addSales(float value) {
        sales += value;
    }

    /**
     * Run all customers in a fixed thread pool
     */
    public void run() {
        availableBread = new ConcurrentHashMap<BreadType, Integer>();
        availableBread.put(BreadType.RYE, FULL_BREAD);
        availableBread.put(BreadType.SOURDOUGH, FULL_BREAD);
        availableBread.put(BreadType.WONDER, FULL_BREAD);

        // TODO
        //initialize thread pool and start customer threads
        
        executor = Executors.newFixedThreadPool(CAPACITY);
        for(int i = 0; i < TOTAL_CUSTOMERS; i++){
            executor.execute(new Customer(this, doneSignal));
        }
        //after all customers are finished, print out the sales
        try{
            doneSignal.await();
        }
        catch (InterruptedException e){
            e.printStackTrace();
        }
        System.out.printf("Total sales = %.2f\n", sales);
       //shutdown the executor service
       executor.shutdown();          

    }
}
